#
import os
# Get the full path to this directory
THIS_DIR  = os.getcwd()
# This with be a dir created and will house all the
# checked out code from git repositories.  No artifacts will be
# created outside of this directory
BUILD_DIR = THIS_DIR + "/build"
# base path where all the respective git repos are housed.  Only
# one value supported.
# ex: 'git@github.com:octocat'
GIT_REPO_BASE_CLONE_PATH = ''
# The user of the script can choose to update all repos or
# a subset of that.  This is the canonical complete list of
# repo names
KNOWN_REPOS_GIT_REPO_NAMES = []
# For each repo (listed via KNOWN_REPOS_GIT_REPO_NAMES, this is the name (git repo name) of
# the submodule to be updated.
TARGET_SUBMODULE_NAME = ''

# the relative path (in contexts of the top dir of a repo using the submodule)
# to the target sub-module
TARGET_SUBMODULE_RELATIVE_PATH = ''

# this is the branch name that target submodule will be pulled to the HEAD of
TARGET_SUBMODULE_TARGET_BRANCH = 'master'