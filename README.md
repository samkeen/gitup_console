## Summary
This is a simple ruby script for updating a submodule shared by multiple repositories. At my place of employment
we have one submodule that is included in 8 repositories.  This script iterates through a list of those repos,
performs checkouts to the local machine, updates the submodule and then pushes the changes back to origin.

All of the checking versions/etc work you see in the app could be handled through the GithubAPI and I do plan in the future to
convert over to using it rather then literal checkouts from Origin.

## Usage

```
bundle install
cp settings.dist.yml settings.yml
```

Configure settings.yml

### Report mode

**regular mode**

If run with just `./report.rb`, progress in output to console and optionally, the results can be emailed to an address 
specified in settings.yml

```
./report.rb


  ... <--output-->
  
  
== Submodule State Report ==

  This job checks the state of the submodule saccharin
  with regards to the Repos that contain that submodule.

== Repos Processed ==

  
  repo_a : current
  
  repo_x : current
  

== Outdated Repo States ==

  This shows the commits that need to be pulled


  NONE outdated so nothing to show here
Mailing report to bob@example.com
```

**CI Server mode (Jenkins)**

If you add --jenkins flag the script runs identical as above except

- If any repos are out of date, the script will `exit 1`, signaling a failure to the CI Server
- The script will not email results (rely on the CI Server for that)
