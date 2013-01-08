import os, sys, subprocess, re, shutil
from Console import *

class Updater:
    """Abstract the updating of a submodule within a git repo"""
    verbose_on = False
    prompt_user_on = False
    settings = None

    def __init__(self, settings, commandline_args):
        self.settings = settings
        self.verbose_on = commandline_args.verbose
        self.prompt_user_on = commandline_args.prompt_user

    def verbose(self, message, type='normal'):
        """
        wrap verbose message output so it can be turned off when not in -v mode

        Parameters
        ----------
        message : str
        type : str (optional) defaults to Console.NORMAL
            one of Console.NORMAL, Console.WARN, Console.ERROR, Console.SUCCESS
        Returns
        ----------
        list
        """
        if self.verbose_on:
            Console.out(message, type)

    def get_menu(self):
        """
        Construct a Selection Menu string
        i.e.
          1) ALL
          2) alley-oop

          Select the Repos to update (space|comma delimited list. i.e. 2 3 7 OR 2, 3, 7): 2

        Returns
        ----------
        str The constructed selection menu intended for the commandline
        """
        menu_list = "  1) ALL\n"
        for index, repo_meta in enumerate(self.settings.KNOWN_REPOS):
            menu_list += "  " + str(index + 2) + ") " + repo_meta['name'] + "\n"
        self.verbose("(note, this list built from settings.KNOWN_REPOS_GITHUB_NAMES)")
        return menu_list

    def get_menu_input(self):
        """
        Capture the user input in response to the menu produced via self.get_menu()

        Returns
        ----------
        list
        """
        input = raw_input("Select the Repos to update (space|comma delimited list. i.e. 2 3 7 OR 2, 3, 7): ")
        # pull the input, trimming out extra space, taking commas into account if present
        input_repos = re.findall(r'\d+', input)
        # convert the 'label index numbers to the actual indexes of the repos list
        return map(lambda x: int(x) - 2, input_repos)

    def get_repos_to_process(self, repo_index_input):
        """
        for the given list of indexes (), return the correlating items
        in settings.KNOWN_REPOS

        Parameters
        ----------
        repo_index_input : list
            List of indexes correlating to settings.KNOWN_REPOS
        Returns
        ----------
        list
        """
        repos_to_clone = []
        for index in repo_index_input:
            if index == -1:
                self.verbose("You've selected ALL repos")
                repos_to_clone = self.settings.KNOWN_REPOS
            elif index >= 0 and index <= (len(self.settings.KNOWN_REPOS) - 1):
                repos_to_clone.append(self.settings.KNOWN_REPOS[index])
            else:
                Console.out("Unknown index: {0}.  Ignoring it".format(index + 2), Console.WARN)
        if repos_to_clone:
            self.verbose("The repos to be processed are: " + ", ".join(map(lambda x: x['name'], repos_to_clone)))
        return repos_to_clone

    def command(self, command_to_run):
        """
        Issue a system command.  Capture any errors

        Parameters
        ----------
        command_to_run : str|list (if str, it is converted to single item list)
            The settings module for this app
        Returns
        ----------
        str The STDOUT result from the command
        """
        if type(command_to_run) is str:
            command_to_run = [command_to_run]
        try:
            p = subprocess.Popen(command_to_run, stdout=subprocess.PIPE)
        except Exception as e:
            Console.out("The command:\n  {0}, returned an error:".format(", ".join(command_to_run)), Console.ERROR)
            Console.out(e, Console.ERROR)
            Console.out("Exiting...", Console.ERROR)
            sys.exit()
        output, error = p.communicate()
        if error:
            Console.out("The command: " + command_to_run + ", returned error[" + error + "]", Console.ERROR)
            Console.out("Exiting...", Console.ERROR)
            sys.exit()
        return output

    def assert_path_exists(self, path, additional_message=''):
        """
        Utility method to assert a filesystem path exists

        Parameters
        ----------
        path : str
            The settings module for this app
        additional_message : str (optional)
            If given, additional message to output if path does
            not exist
        Returns
        ----------
        None (exit if path not exists)
        """
        if not os.path.exists(path):
            Console.out("path [" + path + "] does not exist", Console.ERROR)
            Console.out(additional_message, Console.ERROR)
            sys.exit()

    def prep_build(self, settings):
        """
        Cleanup from previous runs of app.
        Create any resources (dirs, etc) for the next build

        Parameters
        ----------
        settings : module
            The settings module for this app

        Returns
        ----------
        None
        """
        self.verbose("Removing build dir at: {0}".format(settings.BUILD_DIR))
        if os.path.isdir(settings.BUILD_DIR):
            shutil.rmtree(settings.BUILD_DIR)
            # create the build dir
        self.verbose("Creating build dir at: {0}".format(settings.BUILD_DIR))
        os.mkdir(settings.BUILD_DIR)

    def clone_repo(self, settings, repo_name):
        """
        Clone the given git repo into the build directory

        Parameters
        ----------
        settings : module
            The settings module for this app
        repo_name : string

        Returns
        ----------
        None
        """
        clone_url = settings.GIT_REPO_BASE_CLONE_PATH + "/{0}.git".format(repo_name)
        clone_target_path = "{0}/{1}".format(settings.BUILD_DIR, repo_name)
        git_command_parts = ['git', 'clone', clone_url, clone_target_path]
        self.verbose("Cloning Repo: {0}".format(repo_name))
        self.verbose("  {0}".format(" ".join(git_command_parts)))
        self.prompt_user_to_continue()
        self.verbose(self.command(git_command_parts))

    def pull_branch_origin_latest(self, branch_name):
        """
        Update to current branch to the latest on origin

        Parameters
        ----------
        branch_name : string

        Returns
        ----------
        None
        """
        self.assert_known_branch(branch_name)
        git_pull_command_parts = ['git', 'pull', 'origin', branch_name]
        self.verbose("issuing command:")
        self.verbose(" ".join(git_pull_command_parts))
        self.verbose(self.command(git_pull_command_parts))

    def assert_known_branch(self, branch_name):
        """
        Assert that the given branch name exists for the current repo

        Parameters
        ----------
        branch_name : string

        Returns
        ----------
        None (exit if branch unknown)
        """
        branch_list = self.get_branch_list()
        if not any(branch_name in s for s in branch_list):
            Console.out("Branch {0} is an unknown branch.  Known branches are [{1}]".format(
                branch_name, ", ".join(branch_list)
            ), Console.ERROR)
            Console("Exiting...", Console.ERROR)
            sys.exit()

    def get_branch_list(self):
        """
        get the list of branched for a git repo

        Returns
        ----------
        list
        """
        self.command(['git', 'fetch'])
        branch_output = self.command(['git', 'branch'])
        return self.strip_list(branch_output.splitlines(), ' *')

    def strip_list(self, l, charset=' '):
        """
        utility method to strip whitespace from a list of strings

        Parameters
        ----------
        l : list
        charset : string (optional)
            string of characters to strip from each item in the list
        Returns
        ----------
        list
        """
        return [x.strip(charset) for x in l]

    def init_submodule(self, submodule_path):
        """
        initialize a git submodule

        Parameters
        ----------
        submodule_path : str
            relative path to the submodule directory
        Returns
        ----------
        None
        """
        self.assert_path_exists(submodule_path, "This is the expected path to the Saccharin submodule")
        init_command_parts = ['git', 'submodule', 'update', '--init', submodule_path]
        self.verbose("initing submodule: {0}".format(submodule_path))
        self.verbose(" ".join(init_command_parts))
        self.verbose(self.command(init_command_parts))

    def prompt_user_to_continue(self, message="Continue [y/N] "):
        """
        Utility method to prompt use to continue or exit

        Parameters
        ----------
        message : str (optional)
            String to use as prompt. defaults to 'Continue [y/N] '
        Returns
        ----------
        None
        """
        if self.prompt_user_on:
            input = raw_input(message)
            if input.upper() != 'Y':
                Console.out("Exiting...", Console.WARN)
                sys.exit()

    def get_current_branch_name(self):
        """
        Get the name of the current git branch

        Returns
        ----------
        str
            The name of the current branch
        """
        branch_name_command_parts = ['git', 'rev-parse', '--abbrev-ref', 'HEAD']
        self.verbose("Determining the current branch name")
        self.verbose("Issuing command: " + " ".join(branch_name_command_parts))
        current_branch = self.command(branch_name_command_parts).strip()
        self.verbose("Current branch name is: {0}".format(current_branch))
        return current_branch

    def checkout_branch(self, branch_name):
        """
        Checkout the given branch (branch_name) for the repo we are currently in

        Parameters
        ----------
        branch_name : str
            The branch name
        Returns
        ----------
        str
            The sha of the checked out branch
        """
        self.assert_known_branch(branch_name)
        current_branch_name = self.get_current_branch_name()
        if branch_name == current_branch_name:
            self.verbose("Already on branch {0}, no need to checkout to that branch".format(branch_name))
        else:
            git_checkout_command_parts = ['git', 'checkout', branch_name]
            self.verbose("Issuing command:")
            self.verbose(" ".join(git_checkout_command_parts))
            self.verbose(self.command(git_checkout_command_parts))
        return self.command(['git', 'rev-parse', 'HEAD']).strip()

    def chdir_to_repo(self, settings, repo_name):
        """
        Helper method to cd into the given (repo_name) repo dir.

        Parameters
        ----------
        settings : module
            The settings module for this app
        repo_name : str
            The repo dir name
        Returns
        ----------
        None
        """
        repo_path = "{0}/{1}".format(settings.BUILD_DIR, repo_name)
        self.assert_path_exists(repo_path, "This is the expected path to the repo: {0}".format(repo_name))
        self.verbose("Changing to dir: {0}".format(repo_path))
        os.chdir(repo_path)

    def chdir_to_repo_submodule(self, settings, repo_name, submodule_relative_path):
        """
        Helper method to cd into the submodule dir (submodule_relative_path) for
        a given (repo_name) repo dir.

        Parameters
        ----------
        settings : module
            The settings module for this app
        repo_name : str
            The repo dir name
        submodule_relative_path : str
            The relative (to repo dir) path to the submodule
        Returns
        ----------
        None
        """
        submodule_path = "{0}/{1}/{2}".format(settings.BUILD_DIR, repo_name, submodule_relative_path)
        self.assert_path_exists(submodule_path,
            "This is the expected path to the repo submodule: {0}".format(submodule_relative_path))
        self.verbose("Changing to dir: {0}".format(submodule_path))
        os.chdir(submodule_path)

    def make_commit(self, commit_message, paths_to_add):
        """
        Parameters
        ----------
        commit_message : str
            Message for the commit
            i.e. git commit -m {commit_message}
        paths_to_add : str|list
            A list of paths to explicitly add for this commit
            i.e. git add {path_add}
        Returns
        ----------
        None
        """
        if type(paths_to_add) is str:
            paths_to_add = [paths_to_add]
        for path in paths_to_add:
            git_add_command_parts = ['git', 'add', path]
            self.verbose("Issuing command:")
            self.verbose(" ".join(git_add_command_parts))
            self.verbose(self.command(git_add_command_parts))
        self.prompt_user_to_continue("\nContinue?[y/N]")
        self.verbose(self.command(['git', 'commit', '-m', '{0}'.format(commit_message)]))

    def push_to_origin(self, branch_name):
        """
        Parameters
        ----------
        branch_name : str
            the branch at origin to push to
        Returns
        ----------
        None
        """
        Console.out("Pushing {0} to origin...".format(branch_name))
        git_push_command_parts = ['git', 'push', 'origin', branch_name]
        Console.out("Issuing command:")
        Console.out(" ".join(git_push_command_parts))
        Console.out(self.command(git_push_command_parts))

    def submodule_up_to_date(self, submodule_relative_path, submodule_target_sha):
        """
        Parameters
        ----------
        submodule_relative_path : str
            With respect to the Repo, the relative path to the submodule
        submodule_target_sha : str
            The sha we expect the submodule to be at in order to be considered
            'up to date'
        Returns
        ----------
        bool
        """
        git_submodule_status_command_parts = ['git', 'submodule', 'status', submodule_relative_path]
        self.verbose("Issuing Command:")
        self.verbose(" ".join(git_submodule_status_command_parts))
        sha_response = self.command(git_submodule_status_command_parts)
        # parsing sha out of this type response -bd5fb0ce3d9646d9afd3cb4007b87d0cf1811a03 src/vendor/saccharin
        repos_submodule_sha = re.findall(r'-([abcdef0-9]+) ', sha_response).pop(0)
        return repos_submodule_sha == submodule_target_sha

    def process_repos(self, repos_to_clone):
        """
        Parameters
        ----------
        repos_to_clone : list
            List of Repos to process.  Each element of the list is a 2 item dict
            with keys: 'name' and 'branch'
            ex: [{name:'', branch:''}, ...]
        Returns
        ----------
        None
        """
        commit_message = raw_input(
            "Commit message for target submodule[{0}]: ".format(self.settings.TARGET_SUBMODULE_NAME))
        # cleanup from the last build
        self.prep_build(self.settings)
        # get the current sha for the head of the target
        # submodule branch
        Console.out("\nDetermining the sha for the HEAD of branch [{0}] of the target submodule [{1}]"
        .format(self.settings.TARGET_SUBMODULE_TARGET_BRANCH, self.settings.TARGET_SUBMODULE_NAME))
        self.clone_repo(self.settings, self.settings.TARGET_SUBMODULE_NAME)
        self.chdir_to_repo(self.settings, self.settings.TARGET_SUBMODULE_NAME)
        submodule_head_sha = self.checkout_branch(self.settings.TARGET_SUBMODULE_TARGET_BRANCH)
        self.verbose("{0} sha is: {1}".format(self.settings.TARGET_SUBMODULE_TARGET_BRANCH, submodule_head_sha))

        # now update each repo
        for repo_meta in repos_to_clone:
            Console.out("\nProcessing repo: {0}".format(repo_meta['name']))
            self.clone_repo(self.settings, repo_meta['name'])
            self.chdir_to_repo(self.settings, repo_meta['name'])
            self.checkout_branch(repo_meta['branch'])
            if not self.submodule_up_to_date(self.settings.TARGET_SUBMODULE_RELATIVE_PATH, submodule_head_sha):
                self.init_submodule(self.settings.TARGET_SUBMODULE_RELATIVE_PATH)
                self.chdir_to_repo_submodule(self.settings, repo_meta['name'],
                                             self.settings.TARGET_SUBMODULE_RELATIVE_PATH)
                self.pull_branch_origin_latest(self.settings.TARGET_SUBMODULE_TARGET_BRANCH)
                self.chdir_to_repo(self.settings, repo_meta['name'])
                self.make_commit(commit_message, self.settings.TARGET_SUBMODULE_RELATIVE_PATH)
                self.push_to_origin(repo_meta['branch'])
            else:
                Console.out("The repo: {0} submodule {1} is already up to date. Skipping"
                .format(repo_meta['name'], self.settings.TARGET_SUBMODULE_NAME), Console.WARN)
