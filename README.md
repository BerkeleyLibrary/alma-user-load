
# Alma-User-Load

Application for fetching patron records for both studens and employees and formatting those records into XML to be loaded by Ex Libris into Alma using their sync process. 

Additional documentation can be found on B-Drive: [link](https://drive.google.com/drive/folders/1qO_7oD4tzDO9H4UMHrms7-ONzHdQ4gU2)

### Important Note
Because of differences in the two APIs (SIS and UCPath), these do not operate exactly the same. UCPath's API is driven by a "change log". When it runs, it looks back 7 days from the current date for any recods that have been added or updated and then processes those. SIS does not have a change log. Instead we pull the entire collection of users for the current semester everytime we run SIS.

If the SIS Alma-User-Load fails to run on it's scheduled day, it's not considered detrimental - the next scheduled run will pick up any new or updated records the previous run would have picked up.

If UCPath **fails to run on it's scheduled day**, a manual run is necessary. The `startdate` (see Commandline Options below) needs to be the date 7 days prior to the scheduled date that was missed.  (e.g., if UCPath was scheduled to run on April 10, 2025 and failed and you wanted to run it on April 11th, you'd need to pass -startdate 2025-04-03 as a commandline arguement).

You can perform that locally and manually copy the zipped file to the patron_employees folder (see XML and Zip File Output below)

## Info

### Dependencies

Alma-User_load is deployed via the Docker Swarm and is kept in the `lap/alma-user-load` repo.  
Data is harvested from several sources:  

UCPath: https://developers.api.berkeley.edu/api/8  
SIS: https://developers.api.berkeley.edu/api/6  
Additional data is pulled from CalNet via LDAP

Note - the sis_ignore_ids.txt file contains a list of student_ids which will be ignored by the SIS run. This is so employees who take classes (usually UC Extension), don't have their Alma UCPath record over-written by their SIS record.

### Schedule

* SIS : Monday and Wednesday Mornings 1am
* UCPath : Thursday Mornings 1am

The schedules are defined in the `ops/docker-swarm`  
repo: `files/production/swarm/stacks/alma_user_loader.yml`

### XML and Zip File Output

Files are saved to:  
SIS: ```upload.lib.berkeley.edu/alma/patron_students```  
UCPath: ```upload.lib.berkeley.edu/alma/patron_employees```

### Logging

Production logs can be found in Amazon CloudWatch under the following log groups:

[production/alma_user_loader/sis](https://us-west-1.console.aws.amazon.com/cloudwatch/home?region=us-west-1#logsV2:log-groups/log-group/production$252Falma_user_loader$252Fsis)  
[production/alma_user_loader/ucpath](https://us-west-1.console.aws.amazon.com/cloudwatch/home?region=us-west-1#logsV2:log-groups/log-group/production$252Falma_user_loader$252Fucpath)

You'll need to sign in with the IAM account alias uc-berkeley-library-it
and then with your IAM user name and password (created by the DevOps team).

In the event Alma-User-Load fails to run:  
SIS: Because SIS pull the full collection of users for the current semester every run, there are no special steps for recovery. You can either let it run 


## Development

### Configuring

To run locally, clone the repo, then add a .env file to the root of the project. (API info can be found in LastPass)  

> \# UCPath Secrets:  
> UCPATH_API_URL=https://gateway.api.berkeley.edu/hr/v3/  
> UCPATH_API_ID=[API ID]  
> UCPATH_API_KEY=[API KEY]  
>  
> \# SIS Secrets:  
> SIS_API_URL=https://gateway.api.berkeley.edu/sis/v2/students  
> SIS_API_ID=[API ID]
> SIS_API_KEY=[API KEY]  
>   
> \# LDAP Secrets:  
> LDAP_HOST=ldap.berkeley.edu  
> LDAP_PASS=[LDAP Password]



### Running

Note - you cannot run students and employees at the same time, you can only run them one at a time.  
Alma-User-Load can be run directly or using Docker.

### Run locally without Docker:

```sh
ruby alma_user_load.rb -t <ucpath|sis>
```

### Run with Docker:

Build the container:
```sh
docker build -t alma-user-load .
```

* Run UCPath:
  ```sh
  docker run -v $PWD:/opt/app --rm alma-user-load -t ucpath
  ```

* Run SIS:
  ```sh
  docker run -v $PWD:/opt/app --rm alma-user-load -t sis
  ```

* Run UCPath for a specific user:
  ```sh
  docker run -v $PWD:/opt/app --rm alma-user-load -t ucpath -u 10192606
  ```

* Run UCPath for a specific user(s) locally:
  ```sh
  ruby alma_user_load.rb -t ucpath -u '10671129,10674086'
  ```

### Run the test suite:
```sh
> rspec
```

### Run the test suite via Docker:
```sh
# Run rspec:
> docker compose -f docker-compose.local.yml run --rm shell bundle exec rspec

# Run a single spec file:
> docker compose -f docker-compose.local.yml run --rm shell bundle exec rspec spec/lib/ucpath_spec.rb

# Run a specific test (by line number)
> docker compose -f docker-compose.local.yml run --rm shell bundle exec rspec spec/lib/helpers_spec.rb:34
```

### For convenience, setup an alias:
```sh
# Add alias:
> alias drspec='docker compose -f docker-compose.local.yml run --rm shell bundle exec rspec'

# Run via alias:
drspec spec/lib/ucpath_spec.rb:327
```

Note - to run the test suite you need to change the LDAP setting in your `.env` file
> \# For testing:  
> LDAP_HOST=ldap.fake.edu  
> LDAP_PASS=FAKEPW  


**Commandline Options**
* --type [ucpath|sis] *required*
* --term [term-code]  *SIS only*
* --startdate  Declare start date [yyyy-mm-dd]
* --enddate    Declare end date [yyyy-mm-dd]
* --outdir Set the output directory for xml/zip files
* --help


## Future Improvements:
- DRY things up (UCPath vs. SIS --> phone, email, address, names, etc...)
- SIS - add run by user id (similar to how I setup ucpath)...if possible
- Move 'create_user_record' from user.rb to a separate class
- Add a check to make sure all necessary config settings are set!
- Setup a rake command to run the test suite
- Reduce some of the complexity so I can remove some of the rubocop disables
