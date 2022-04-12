
# Alma-User-Load

Application for fetching patron records for both SIS (aka students) and UCPath (aka employees) and formatting those records into XML to be loaded by Ex Libris into Alma using their sync process. Ex Libris pulls the XML files from our SFTP server.

Additional documentation can be found on B-Drive: [link](https://drive.google.com/drive/folders/1pOEKi2d5SQ4VZpwjQzUwuArwBbUJzvcF)

___

#### Info
Alma-User_load is deployed via the Dockar Swarm.
It is kept in the `lap/alma-user-load` repo.

#### Schedule
SIS : Wednesday Mornings 1am
UCPath : Thursday Mornings 1am

The schedules are defined in the `ops/docker-swarm` repo:
`files/production/swarm/stacks/alma_user_loader.yml`

#### XML Output
Files are saved to:
SIS: ```upload.lib.berkeley.edu/alma/patron_students```
UCPath: ```upload.lib.berkeley.edu/alma/patron_employees```

#### Logging
Production logs can be found in Amazon CloudWatch under the following log groups:

[production/alma_user_loader/sis](https://us-west-1.console.aws.amazon.com/cloudwatch/home?region=us-west-1#logsV2:log-groups/log-group/production$252Falma_user_loader$252Fsis)
[production/alma_user_loader/ucpath](https://us-west-1.console.aws.amazon.com/cloudwatch/home?region=us-west-1#logsV2:log-groups/log-group/production$252Falma_user_loader$252Fucpath)

You'll need to sign in with the IAM account alias uc-berkeley-library-it
and then with your IAM user name and password (created by the DevOps team).

---
## Development
#### Configuring
After cloning the repo in order to run locally you will need to add a .env file to the root of the project. Check `config>secrets.yml` for necessary UCPath, SIS and LDAP settings.

#### Running
Note - you cannot run students and employees at the same time, you can only run them one at a time.

You can run this directly or using Docker

##### Run locally without Docker:
```sh
ruby alma_user_load.rb -t <ucpath|sis>
```

##### Run with Docker:
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

**Commandline Options**
* --type [ucpath|sis] *required*
* --term [term-code]
* --startdate  Declare start date [yyyy-mm-dd]
* --enddate    Declare end date [yyyy-mm-dd]
* --help

___

##### Future Improvements:
- Move zip functionality to a separate class/module
- Clean up options
- Clean up file naming code...move to separate class, it's hacky right now
- Move ucpath/sis processes from alma_user_load.rb to separate modules/classes
- Get "current term" dynamically from API (awaiting access to API)
- Setup SIS so I can set the look back date, or even date range via commandline
- Verify I have all "required" fields for eligibility
- Replace fixtures w/some sort of factory (factorybot?)
- SIS - Check on Identifiers logic (student-id particularly)
- Write test to check that we make expected job date in past ineligible!
- DRY things up (UCPath vs. SIS --> phone, email, address, names, etc...)
- SIS - add run by user id (similar to how I setup ucpath)
- Test a student in sandbox (regular student user...not admin)
- Move 'create_user_record' from user.rb to a separate class
- Add a check to make sure all necessary config settings are set!
