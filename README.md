# Platform.sh Project Migration
This utility allows very ealsy to transfer project from one Platform.sh instance to another.

## Requirements
1. You need to have installed [Platform.sh CLI](https://docs.platform.sh/gettingstarted/cli.html) 
2. You need to have "admin" access to both Platform.sh projects (current one, and the one where you want to migrate your project)
3. Both Platform.sh projects should have the same resources (disk/CPU). Otherwise, it might be impossible to sync some mounts/start some services on the new Platform.sh project.
4. If your project has multiple domains, it is a good idea to make them CNAME of your internal DNS record. And point your internal DNS record to Platform.sh. It will make DNS switching step much simpler. Example:
```
domain1.com  =>
domain2.com  =>
domain3.com  => <project>.ccplatform.net => <platform.sh edge_hostname> 
....         =>
domainX.com  =>
``` 

## Usages
In order to migrate a project from one Platform.sh instance to another you need to do following steps:
1. Setup Platform.sh project IDs: 

    ```
    ./steps/set_projects.sh <FROM_PROJECT_ID> <TO_PROJECT_ID>
    ```
2. Copy project title, users, variables and setup deploy key:

    ```
    ./steps/copy_project.sh
    ```
    
3. For each environment you need to: copy it, update its settings, copy environment variables and copy GIT branches:  

    ```
    ./steps/copy_environment.sh master
    ./steps/copy_environment.sh stage
    ``` 
4. Sync data (mounts, DB) for each environment:

    ```
    ./steps/copy_data.sh master
    ./steps/copy_data.sh stage
    ```
    
5. Remove all assigned domains from old project and assign them to new one:

    ```
    ./steps/project/transfer_domains.sh
    ```

Alternatively you can run following command, it will do all the steps above for `master`, `stage` and `uat` environments:
```
./migrate.sh <FROM_PROJECT_ID> <TO_PROJECT_ID> master,stage,uat
```
And you can sync the rest environments manually:
```
./steps/copy_environment.sh feature1
./steps/copy_data.sh feature1
./steps/copy_environment.sh feature2
./steps/copy_data.sh feature2
```

## Manual actions
Please note, this script will ask to make some manual actions:
1. Setup new deployment SSH key
2. Set correct value for sensitive project/environment variables (as it is impossible to get those values using Paltform.sh CLI)
3. Point project domains to new `edge_hostname`

But there are some other things you need to set up manually, and there will be no prompt for them in the script:
1. Setup non admin users
2. Update HTTP access control settings (most likely for non master environments)
3. Script takes care only about `database` database relation. If you are using another name for it (or have multiple database relations) you need to tune [copy_db.sh](https://gitlab.com/contextualcode/project-migration-platform.sh/blob/master/steps/environment/data/copy_db.sh)
4. Copy persistent data for additional services (Solr/Elasticsearch/etc)