# Alma User Loader

##### Build the Container:
    docker build -t alma-user-load .

##### Run the Container: (for ucpath, user 10192606)
    docker run -v $PWD:/opt/app --rm alma-user-load -t ucpath -u 10192606
___

**Types**
* UCPath - Employees (uses UCPath API and LDAP)
* SIS - Students (uses SIS Students API)

___

####TO-DO FOR GO LIVE!
STARTED - Setup DockerFile
Setup in pipeline
Write up README

####TO-DO Eventually:
- Setup config setup and options
- SEGREGATE THE UCPATH AND SIS PROCESSES Above TO MODULES
- Verify I have all "required" fields for eligibility
- Replace fixtures w/some sort of factory (factorybot?)
- REFACTOR...then refactor more!
- SIS - Check on Identifiers logic (student-id particularly)
- SIS - Improve logging!!!
- Improve error handling
- Write test to check that we make expected job date in past ineligible!
- Setup full user base run (if we want that)
- DRY things up (UCPath vs. SIS --> phone, email, address, names, etc...)
- Save the change log to a temp file and go through (and track your progress)
- Only do a LDAP lookup if you have an eligible job!!!
- Go through the million "TODOs" littered through all this code!
- Eventually build out custom logger (CSV of each record touched, each event and outcome)
- Add some resiliency - maybe log progress so if there is an interuption I can restart from the last place
- SIS - add run by user id (similar to how I setup ucpath)
- Test a student in sandbox (regular student user...not admin)
- Get "current term" dynamically from API
- Move 'create_user_record' from user.rb to a separate class
- Add a check to make sure all necessary config settings are set!
- Maybe if missing needed .env locally I can offer a command line option to create a skeleton .env file.
- move zip functionality to a separate class/module