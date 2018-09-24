Usage:
```
./run.sh <FROM_PROJECT_ID> <TO_PROJECT_ID> <ENV>
```
Alternatively:
```
./steps/set_projects.sh <FROM_PROJECT_ID> <TO_PROJECT_ID>
./steps/copy_project.sh
...
./steps/copy_environment.sh master
./steps/copy_data.sh master
...
./steps/copy_environment.sh stage
./steps/copy_data.sh stage
```

[TODO]
- add readme
- sync domains
