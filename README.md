This is a simple ruby script for updating a submodule shared by multiple repositories. At my place of employment
we have one submodule that is included in 8 repositories.  This script iterates through a list of those repos,
performs checkouts to the local machine, updates the submodule and them pushes the changes back to origin.

All of the checking versions/etc work you see in the app could be handled through the GithubAPI and I do plan in the future to
convert over to using it rather then literal checkouts from Origin.

But currently we do need to run processes locally that can add resources to the repo after it's submodule has been
updates (our current autoload strategy necessitates this), so we do still need the code checked out locally in order
to push submodule updated repos back to origin.