# repo_utils
Utilities to automate operations over local git repositories.  

## why this exists

Working with multiple git repositories locally involves executing **highly repetitive routine steps**, typically clustered around:

- Initial repository setup – configuring local user identity and git parameters 
- Review-add-commit-push cycles – completing blocks of work

Most routine steps are chains of **git commands**. Some workflows also benefit from **copying files** in or out of the repository before committing - for example, version controlling Google Colab notebooks stored in Google Drive.  

Semantically, these routine steps are **not part of the project** itself. They represent the workflow preferences of individuals working on the project.  

The **repo-utils** project stores and executes these **configurable repeatable automations over a local git repository**. It's particularly valuable for:

- **Unobtrusive run of helper utilities**:
    - blends into a larger repository as a sub-repository without polluting the parent's git history
- **Git workflows automation**:
    - sets up multiple projects with different git configurations (user identities, line endings, default branch)
    - automates repetitive chains of git commands (status, add, commit, push)
- **Notebook-centric development**:
    - automatically syncs Jupyter notebooks, simplifying integration with Google Colab as explained in [git-gdrive-sync](https://github.com/olga-terekhova/git-gdrive-sync)
    - cleans the notebooks before commits, removing cell outputs and execution counts from git diffs 

Repo-utils operates in two modes:

- **Attached mode** – repo-utils connects to another repository (the host) and runs procedures over the host. The host repository doesn't see or track repo-utils.
- **Detached mode** – repo-utils operates standalone, running procedures over itself. It tracks itself and allows committing changes to the repo-utils repository.

Repo-utils maintains separate settings for itself and for the host.  

**Suggested workflow:**  
1. **Fork this repository.**:
    - Your fork will serve as the central repository where you'll maintain your customized automation scripts and configurations.
    - You'll deploy shallow clones of this fork to individual projects while maintaining the full repository for development.
2. **Use automations on other projects:**
    - Shallow clone your fork into the target project:
        ```
        git clone --depth 1 [your-fork-url]
        ```
    - Run `.\config\Assume-Attached.ps1` (one-time setup) 
    - Run `.\config\Config-WorkRepo.ps1` (one-time configuration)
    - Run `.\scripts\Sync-All.ps1` for regular automations over the host repository
2. **Extend repo-utils functionality:**
    - Clone your fork into a dedicated folder  (optionally within a test repository) 
    - Run `.\config\Assume-Detached.ps1` (one-time setup) 
    - Run `.\config\Config-WorkRepo.ps1` (one-time configuration)
    - Implement and test changes  
    - Switch between attached mode (testing) and detached mode (committing changes)
    - Run `.\scripts\Sync-All.ps1` to commit changes to your repo-utils fork 
    - To propagate changes to clones attached to other projects:
        - Detach a clone to pull updates from the main repo-utils repository
        - Attach the clone back into attached mode


