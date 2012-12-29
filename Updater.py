import os, sys, subprocess, re, shutil
from Colors import *

class Updater:
    """Abstract the updating of a submodule within a git repo"""
    verbose_on       = False
    settings         = None
    commandline_args = None

    def __init__(self, settings, commandline_args):
        self.settings  = settings
        self.commandline_args  = commandline_args

    def message(self, message, type='normal'):
        """output a message to standard out if -v is enabled"""
        message_prefix = ''
        message_suffix = ''
        if type == 'warning':
            message_prefix = self.colorizer.WARNING
            message_suffix = self.colorizer.END
        elif type == 'error':
            message_prefix = self.colorizer.FAIL
            message_suffix = self.colorizer.END

        print "{0}{1}{2}\n".format(message_prefix, message, message_suffix)

    def get_menu(self):
        menu_list = "  1) ALL\n"
        for index, repo_name in enumerate(self.settings.KNOWN_REPOS_GIT_REPO_NAMES):
            menu_list += "  " + str(index + 2) + ") " + repo_name + "\n"
        if self.commandline_args.verbose:
            menu_list += "(note, this list built from settings.KNOWN_REPOS_GITHUB_NAMES)"
        return menu_list

    def get_menu_input(self):
        input = raw_input("Select the Repos to update (space|comma delimited list. i.e. 2 3 7 OR 2, 3, 7): ")
        # pull the input, trimming out extra space, taking commas into account if present
        input_repos = re.findall(r'\d+', input)
        return map(lambda x: int(x) - 2, input_repos)

    def get_repos_to_process(self, repo_index_input):
        repos_to_clone = []
        for index in repo_index_input:
            if index == -1:
                print "Selected ALL"
                repos_to_clone = self.settings.KNOWN_REPOS_GIT_REPO_NAMES
            elif index >= 0 and index <= (len(self.settings.KNOWN_REPOS_GIT_REPO_NAMES) -1):
                repos_to_clone.append(self.settings.KNOWN_REPOS_GIT_REPO_NAMES[index])
                print "The Repo is: {0}".format(self.settings.KNOWN_REPOS_GIT_REPO_NAMES[index])
            else:
                print "Unknown index: {0}.  Ignoring it".format(index + 2)
        return repos_to_clone

    def command(self, command_to_run):
        if type(command_to_run) is str:
            command_to_run = [command_to_run]
        try:
            p = subprocess.Popen(command_to_run, stdout=subprocess.PIPE)
        except Exception as e:
            print "The command:\n  {0}, returned an error:".format(", ".join(command_to_run))
            print e
            print "Exiting..."
            sys.exit()
        output, error = p.communicate()
        if error:
            print "The command: " + command_to_run + ", returned error[" + error + "]"
            print "Exiting..."
            sys.exit()
        return output

    def assert_path_exists(self, path, additional_message=''):
        if not os.path.exists(path):
            print "path [" + path + "] does not exist"
            print additional_message
            sys.exit()

    def prep_build(self, settings):
        # clean
        self.message("Removing build dir at: {}".format(settings.BUILD_DIR))
        if os.path.isdir(settings.BUILD_DIR):
            shutil.rmtree(settings.BUILD_DIR)
            # create the build dir
        self.message("Creating build dir at: {}".format(settings.BUILD_DIR))
        os.mkdir(settings.BUILD_DIR)

    def clone_repo(self, settings, repo_name):
        clone_url = settings.GIT_REPO_BASE_CLONE_PATH + "/{0}.git".format(repo_name)
        clone_target_path = "{0}/{1}".format(settings.BUILD_DIR, repo_name)
        git_command_parts = ['git', 'clone', clone_url, clone_target_path]
        self.message("Cloning Repo: {0}".format(repo_name))
        self.message("  {0}".format(" ".join(git_command_parts)))
        self.prompt_user_to_continue()
        print self.command(git_command_parts)

    def pull_branch_origin_latest(self, branch_name):
        self.assert_known_branch(branch_name)
        git_pull_command_parts = ['git', 'pull', 'origin', branch_name]
        self.message("issuing command:")
        self.message(" ".join(git_pull_command_parts))
        print self.command(git_pull_command_parts)

    def assert_known_branch(self, branch_name):
        branch_list = self.get_branch_list()
        if not any(branch_name in s for s in branch_list):
            print "Branch {0} is an unknown branch.  Known branches are [{1}]".format(
                branch_name, ", ".join(branch_list)
            )
            print "Exiting..."
            sys.exit()

    def get_branch_list(self):
        """
        :rtype : List
        """
        self.command(['git', 'fetch'])
        branch_output = self.command(['git', 'branch'])
        return self.strip_list(branch_output.splitlines(), ' *')

    def strip_list(self, l, charset=' '):
        return [x.strip(charset) for x in l]

    def get_repo_origin_branch_head_sha(self, settings, repo_name, branch_name):
        self.clone_repo(settings, repo_name)
        self.chdir_to_repo(repo_name)
        self.assert_known_branch(branch_name)

        # git rev-parse HEAD


    def init_submodule(self, submodule_path):
        self.assert_path_exists(submodule_path, "This is the expected path to the Saccharin submodule")
        init_command_parts = ['git', 'submodule', 'update', '--init', submodule_path]
        self.message("initing submodule: {0}". format(submodule_path))
        self.message(" ".join(init_command_parts))
        print self.command(init_command_parts)

    def prompt_user_to_continue(self, message="Continue [y/N] "):
        input = raw_input(message)
        if input.upper() != 'Y':
            print "Exiting..."
            sys.exit()

    def checkout_branch(self, branch_name):
        """
        :rtype : String The sha of the HEAD of the branch checked out.
        """
        self.assert_known_branch(branch_name)
        git_checkout_command_parts = ['git', 'checkout', branch_name]
        self.message("Issuing command:")
        self.message(" ".join(git_checkout_command_parts))
        print self.command(git_checkout_command_parts)
        return self.command(['git', 'rev-parse', 'HEAD']).strip()

    def chdir_to_repo(self, settings, repo_name):
        repo_path = "{0}/{1}".format(settings.BUILD_DIR, repo_name)
        self.assert_path_exists(repo_path, "This is the expected path to the repo: {0}". format(repo_name))
        self.message("Changing to dir: {0}".format(repo_path))
        os.chdir(repo_path)

    def chdir_to_repo_submodule(self, settings, repo_name, submodule_relative_path):
        submodule_path = "{0}/{1}/{2}".format(settings.BUILD_DIR, repo_name, submodule_relative_path)
        self.assert_path_exists(submodule_path, "This is the expected path to the repo submodule: {0}". format(submodule_relative_path))
        self.message("Changing to dir: {0}".format(submodule_path))
        os.chdir(submodule_path)

    def make_commit(self, commit_message, path_adds):
        if type(path_adds) is str:
            path_adds = [path_adds]
        for path in path_adds:
            git_add_command_parts = ['git', 'add', path]
            self.message("Issuing command:")
            self.message(" ".join(git_add_command_parts))
            self.message(self.command(git_add_command_parts))
        self.prompt_user_to_continue("\nContinue?[y/N]")
        output = self.command(['git', 'commit', '-m', '{0}'.format(commit_message)])
        self.message(output)

    def push_to_origin(self, branch_name):
        self.message("Pushing {0} to origin...".format(branch_name))
        git_push_command_parts = ['git', 'push', 'origin', branch_name]
        self.message("Issuing command:")
        self.message(" ".join(git_push_command_parts))
        output = self.command(git_push_command_parts)
        self.message(output)

    def test_for_need_to_update_submodule(self, origin_branch_name):
        # git diff origin/master should return empty string
        git_diff_command_parts = ['git', 'diff', "origin/{0}".format(origin_branch_name)]

    def submodule_up_to_date(self, submodule_relative_path, submodule_target_sha):
        git_submodule_status_command_parts = ['git', 'submodule', 'status', submodule_relative_path]
        self.message("Issuing Command:")
        self.message(" ".join(git_submodule_status_command_parts))
        sha_response = self.command(git_submodule_status_command_parts)
        # -bd5fb0ce3d9646d9afd3cb4007b87d0cf1811a03 src/vendor/saccharin
        repos_submodule_sha = re.findall(r'-([abcdef0-9]+) ', sha_response).pop(0)
        return repos_submodule_sha == submodule_target_sha

    def process_repos(self, repos_to_clone):
        commit_message = raw_input('Commit message for Saccharin:')
        # cleanup from the last build
        self.prep_build(self.settings)
        # get the current sha for the head of the target
        # submodule branch
        self.message("First off, retrieving the sha for the HEAD of the target submodule repo {0}, branch: {1}  "
                     .format(self.settings.TARGET_SUBMODULE_NAME, self.settings.TARGET_SUBMODULE_TARGET_BRANCH))
        self.clone_repo(self.settings, self.settings.TARGET_SUBMODULE_NAME)
        self.chdir_to_repo(self.settings, self.settings.TARGET_SUBMODULE_NAME)
        submodule_head_sha = self.checkout_branch(self.settings.TARGET_SUBMODULE_TARGET_BRANCH)
        print "{0} sha is: {1}".format(self.settings.TARGET_SUBMODULE_TARGET_BRANCH, submodule_head_sha)

        # now update each repo
        for repo_name in repos_to_clone:
            self.clone_repo(self.settings, repo_name)
            self.chdir_to_repo(self.settings, repo_name)
            if not self.submodule_up_to_date(self.settings.TARGET_SUBMODULE_RELATIVE_PATH, submodule_head_sha):
                self.init_submodule(self.settings.TARGET_SUBMODULE_RELATIVE_PATH)
                self.chdir_to_repo_submodule(self.settings, repo_name, self.settings.TARGET_SUBMODULE_RELATIVE_PATH)
                self.pull_branch_origin_latest(self.settings.TARGET_SUBMODULE_TARGET_BRANCH)
                self.chdir_to_repo(self.settings, repo_name)
                self.make_commit(commit_message, self.settings.TARGET_SUBMODULE_RELATIVE_PATH)
                self.push_to_origin('development')
            else:
                self.message("The repo: {0} submodule {1} is already up to date. Skipping"
                .format(repo_name, self.settings.TARGET_SUBMODULE_NAME), 'warning')