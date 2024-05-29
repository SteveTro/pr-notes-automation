import os
import sys
import re
from github import Github, GithubException
import git

# Input variables
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
INPUT_BASE_BRANCH = os.getenv("INPUT_BASE_BRANCH")
INPUT_RELEASE_BRANCH = os.getenv("INPUT_RELEASE_BRANCH")
INPUT_TEMPLATE = os.getenv("INPUT_TEMPLATE")
INPUT_JIRA_BASE_URL = os.getenv("INPUT_JIRA_BASE_URL")

print(f"INPUT_BASE_BRANCH: {INPUT_BASE_BRANCH}")
print(f"INPUT_RELEASE_BRANCH: {INPUT_RELEASE_BRANCH}")
print(f"INPUT_TEMPLATE: {INPUT_TEMPLATE}")
print(f"INPUT_JIRA_BASE_URL: {INPUT_JIRA_BASE_URL}")
print(f"GITHUB_REPOSITORY: {os.getenv('GITHUB_REPOSITORY')}")

# Check if required environment variables are set
if not INPUT_BASE_BRANCH or not INPUT_RELEASE_BRANCH or not INPUT_TEMPLATE:
    print("Required environment variables are not set. Exiting...")
    sys.exit(1)

if not os.path.isfile(INPUT_TEMPLATE):
    print("Release template not found. Exiting...")
    sys.exit(1)

with open(INPUT_TEMPLATE, "r") as file:
    TEMPLATE = file.read()

# Initialize placeholders
ticket_categories = {"feature": "", "bugfix": "", "maintenance": "", "other": ""}

# Initialize GitHub instance
g = Github(os.getenv("GITHUB_TOKEN"))

# Verify the GITHUB_REPOSITORY environment variable
repository_name = os.getenv("GITHUB_REPOSITORY")
if not repository_name:
    print("Error: GITHUB_REPOSITORY environment variable is not set.")
    exit(1)

# Get the repository
try:
    repo = g.get_repo(repository_name)
    print(f"Successfully accessed repository: {repository_name}")
except GithubException as e:
    print(f"Error accessing repository: {repository_name}")
    print(e.data)
    exit(1)

repo_path = "/github/workspace"
git_repo = git.Repo(repo_path)

git_repo.git.config("--global", "--add", "safe.directory", repo_path)
remote_url = f"https://{os.getenv('GITHUB_TOKEN')}@github.com/{os.getenv('GITHUB_REPOSITORY')}.git"
git_repo.git.remote("set-url", "origin", remote_url)

git_repo.git.fetch("--all")


# Get commit messages between base and release branch
log_output = git_repo.git.log(
    "--oneline", f"{INPUT_BASE_BRANCH}...{INPUT_RELEASE_BRANCH}"
)

commit_messages = []
for line in log_output.split("\n"):
    # Check if commit is a PR => message ends with (#XXXX)
    if re.search(r"\(\#[0-9]+\)$", line):
        # Skip lines containing "release/*" or "Main > dev"
        if re.search(r"release/|Main > dev", line, re.IGNORECASE):
            continue
        # Remove the commit hash from the line
        line = re.sub(r"^[0-9a-f]{7,}\s+", "", line)
        commit_messages.append(line)

print("Commit Messages:", commit_messages)

if not commit_messages:
    print(
        f"No commit messages found between {INPUT_BASE_BRANCH} and {INPUT_RELEASE_BRANCH}"
    )
else:
    for line in commit_messages:
        print(f"Working on {line}")
        ticket_number = re.search(r"[A-Za-z]+-[0-9]+", line)
        pr_number = re.search(r"#[0-9]+", line)

        print(f"Ticket: {ticket_number}, PR: {pr_number}")

        ticket_number = ticket_number.group(0) if ticket_number else None
        pr_number = pr_number.group(0) if pr_number else None

        print(f"Ticket: {ticket_number}, PR: {pr_number}")

        pr = repo.get_pull(int(pr_number[1:])) if pr_number else None
        branch_name = pr.head.ref if pr else None

        commit_type = "other"
        if branch_name:
            for category in ticket_categories.keys():
                if branch_name.startswith(category):
                    commit_type = category
                    break

        curr_line = (
            f"- [ ] [{line}]({INPUT_JIRA_BASE_URL}{ticket_number})\n"
            if ticket_number
            else f"- [ ] {line}\n"
        )
        print(f"CURR_LINE {curr_line}")

        ticket_categories[commit_type] += curr_line


output = TEMPLATE
for category, tickets in ticket_categories.items():
    if tickets:
        tickets = f"### {category.capitalize()}:\n{tickets}"
    output = output.replace(f"{{{category.upper()}_TICKETS}}", tickets)

with open("temp_release.md", "w") as file:
    file.write(output)

print(output)
print("temp_release.md created successfully")
