
# Alma-User-Load

Application for fetching patron records for both SIS (aka students) and UCPath (aka employees) and formatting those records into XML to be loaded by Ex Libris into Alma using their sync process. 

Ex Libris pulls the XML files from our SFTP server.
UCPath: upload.lib.berkeley.edu/alma/patron_employees
SIS: upload.lib.berkeley.edu/alma/patron_students

Additional documentation can be found on B-Drive: [link](https://drive.google.com/drive/folders/1pOEKi2d5SQ4VZpwjQzUwuArwBbUJzvcF)

___

#### Info
Alma-User_load is deployed via the Docker Swarm.
It is kept in the `lap/alma-user-load` repo.

#### Schedule
SIS : Monday and Wednesday Mornings 1am
UCPath : Thursday Mornings 1am

The schedules are defined in the `ops/docker-swarm` repo:
`files/production/swarm/stacks/alma_user_loader.yml`

#### XML and Zip File Output
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
To run locally, clone the repo, then add a .env file to the root of the project. Check `config>secrets.yml` for necessary UCPath, SIS and LDAP settings.

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

* Run UCPath for a specific user(s) locally:
  ```sh
  ruby alma_user_load.rb -t ucpath -u '10671129,10674086'
  ```

**Commandline Options**
* --type [ucpath|sis] *required*
* --term [term-code]  *SIS only*
* --startdate  Declare start date [yyyy-mm-dd]
* --enddate    Declare end date [yyyy-mm-dd]
* --outdir Set the output directory for xml/zip files
* --help

___

##### Future Improvements:
- Get "current term" dynamically from API (awaiting access to API)
- Replace fixtures w/some sort of factory (factorybot?)
- DRY things up (UCPath vs. SIS --> phone, email, address, names, etc...)
- SIS - add run by user id (similar to how I setup ucpath)
- Move 'create_user_record' from user.rb to a separate class
- Add a check to make sure all necessary config settings are set!
- Add run by campus-uid to ucpath
