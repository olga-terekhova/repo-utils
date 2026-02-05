# repo_utils
Utilities to automate operations over local git repositories.  

## why this exists

Working with multiple git repositories locally involves executing highly repetitive routine steps, typically clustered around:

- **Initial repository setup** – configuring local git parameters and user identity
- **Review-add-commit-push cycles** – completing blocks of work

Most routine steps are chains of git commands. Some workflows also benefit from copying files in or out of the repository before committing – for example, version controlling Google Colab notebooks stored in Google Drive.  

**These routine steps aren't semantically part of the project itself. They represent the workflow preferences of individuals working on the project.**  

The **repo-utils** project stores and executes these repeatable automations over a local git repository. It's particularly valuable for:

- **Multi-repository workflows** – managing multiple projects with different git configurations (different user identities, push targets, or automation steps)
- **Notebook-centric development** – automatically syncing and cleaning Jupyter notebooks before commits, keeping diffs focused on code changes rather than output noise
- **Complex push workflows** – pushing to multiple remotes or branches in a single command
- **Repository-as-context** – working on a sub-project within a larger repository without polluting the parent's git history

Repo-utils operates in two modes:

- **Attached mode** – repo-utils connects to another repository (the host) and runs procedures over the host. The host repository doesn't see or track repo-utils.
- **Detached mode** – repo-utils operates standalone, running procedures over itself. It tracks itself and allows committing changes to the repo-utils repository.

Repo-utils maintains separate settings for itself and for host repositories.  

**Suggested workflow:**  
1. In attached mode, configure settings for the host repository and use repo-utils to run automated procedures.
2. When you need to modify or evolve the procedures, detach repo-utils, implement and commit changes, then reattach it.
