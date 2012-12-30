#!/usr/bin/env python

__author__ = 'sam keen'
from Updater import *
from Console import *
import argparse, settings

# grab the commandline arguments
parser = argparse.ArgumentParser(description="This is a script that updates a git repo's submodule")
parser.add_argument('-v', help='verbose output', action="store_true", dest='verbose', default=False)
parser.add_argument('-p', help='prompt user to continue for all git interactions', action="store_true", dest='prompt_user', default=False)
commandline_args = parser.parse_args()

updater = Updater(settings, commandline_args)

print updater.get_menu()

input_repo_indexes = updater.get_menu_input()

repos_to_clone = updater.get_repos_to_process(input_repo_indexes)

if repos_to_clone:
    updater.process_repos(repos_to_clone)
else:
    print Console.out("No valid repo indexes found, nothing to process", Console.WARN)