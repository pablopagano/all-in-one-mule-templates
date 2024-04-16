# all-in-one-mule-templates


- [all-in-one-mule-templates](#all-in-one-mule-templates)
  - [Templates](#templates)
  - [Deployment Script for Mule and RAML Projects](#deployment-script-for-mule-and-raml-projects)
    - [Overview](#overview)
    - [Prerequisites](#prerequisites)
    - [Usage](#usage)
    - [Script Features](#script-features)
    - [Customization](#customization)
  - [Authors](#authors)



## Templates 
This repository contains all the templates projects as a form of  [git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) to facilitate the managment of the entire set.

These are the related projects used:

* [common-parent-pom](https://github.com/mulesoft-consulting/common-parent-pom)
* [mule-application-template](https://github.com/mulesoft-consulting/mule-application-template)
* [common-traits-lib](https://github.com/mulesoft-consulting/common-traits-lib)
* [design-api-template](https://github.com/mulesoft-consulting/design-api-template)
* [dw-library-log-mapper](https://github.com/mulesoft-consulting/dw-library-log-mapper)
* [health-check-app](https://github.com/mulesoft-consulting/health-check-app)
* [dw-library-error-mapper](https://github.com/mulesoft-consulting/dw-library-error-mapper)
* [mule-application-template](https://github.com/mulesoft-consulting/dw-library-error-mapper)


## Deployment Script for Mule and RAML Projects

### Overview

A tipical usage scenario for these templates is to create branches for a specific usage or customer on each of them and upload them to Anypoint Exchange.
The **deploy_script.sh**  is designed to streamline the deployment process for Mule and RAML templates. It automates tasks such as creating local git branches, deploying Maven projects, and handling specific tasks for different project types (Maven, RAML API, RAML Fragment).

### Prerequisites

Before using the script, ensure that the following prerequisites are met:

- **Bash:** should be present on your system
- **Maven:** version *3.9* or higher is required
- **jq**: jq must be present on the system
- **Git:**  should be installed on the system.
- **Java:** version *1.8* or higher is required. Used to import **Maven** projects
- **Anypoint CLI V4:** should be present on your system. Used to import **RAML** projects. 
- **Connected app**: The app requires a Connected App credentials, with the following scopes:
    | Component     | Scope                   |
    | ------------- | ----------------------- |
    | Design center | Design Center Developer |
    | Exchange      | Exchange Contributor    |
    | General       | View Environment        |
    | General       | View Organization       |
   




### Usage


1. Ensure to clone this project using the  "--recurse" flag, so that the submodules projects are populated:

   ```
    git clone git@github.com:mulesoft-consulting/all-in-one-mule-templates.git --recursive
   ```

2. Ensure all the git submodules are updated and at the right version:

   ```
    git submodule update --remote
   ```

3. (Optional) Configure the file (`deploy_config.csv`) according to your project structure. The file is used to instruct the tool about the projects to import.  
The file follows the CSV format and has the the following fields:

     | Parameter       | Description                                                                                            |
     | --------------- | ------------------------------------------------------------------------------------------------------ |
     | `project_name`  | the name of the git directory for the project to import, for example: "common-parent-pom"              |
     | `project_type`  | the type of project to import, it can be: **maven**, **raml**, **raml-fragment**                       |
     | `is_template`   | **true** if the project to import is an application template. Valid only for project of type **maven** |
     | `should_import` | **true** if the project has to be imported, **false** if the script should skip it                     |


4. Execute the deployment script:

   ```bash
   ./deploy_script.sh [-w] [-g] [-d] <customer_name> <organization_id> <connected_app_id> <connected_app_secret>
   ```

   Replace the placeholder values with your actual input.
   This is a description of the parameters:

    | Parameter                | Description                                                                                                                                                                                               |
    | ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
    | `-w`                     | (Optional) if present, specifies whether to use the **maven wrapper** included in this repository (./mvnw) or the global maven installation                                                               |
    | `-g`                     | (Optional) if present, the script will attempt to create **local git branches** on each project's directory to import. The branch will be created with the following format: **customer/<customer_name>** |
    | `-d`                     | (Optional) if present, specifies whether the **US control plane** should be used, the **EU control plane** is assumed otherwise                                                                           |
    | `<customer_name>`        | A string representing the customer name.                                                                                                                                                                  |
    | `<organization_id>`      | A string representing the organization ID.                                                                                                                                                                |
    | `<connected_app_id>`     | A string representing the connected app ID.                                                                                                                                                               |
    | `<connected_app_secret>` | A string representing the connected app secret.                                                                                                                                                           |

### Script Features

- **Java, Maven, Anypoint CLI V4 Version Checks:** The script checks whether the required versions of Java, Maven and Anypoint CLI V4 are installed.

- **Project Type Support:** The script supports different project types, including Maven projects, RAML API projects, and RAML Fragment projects.

- **Placeholder Replacement:** The script replaces the `GROUP_ID` placeholder in the `pom.xml`, `api.raml`, and `exchange.json` files.

- **Git Branch Creation:** The script creates a local git branch for each project.

- **Maven Deployment:** For Maven projects, the script executes the `mvn clean deploy` command. For RAML API projects, it additionally renames directories within `exchange_modules` and runs the `designcenter:project:create` command.

### Customization

- **Project Configuration:** Update the `deploy_config.csv` file to include your specific project names and types.

- **Command Customization:** Modify the script to include additional commands or customize existing commands based on your project requirements.

## Authors

Contributors names and contact info

Marco Iarussi - miarussi@salesforce.com  
Patryk Sobczak - patryk.sobczak@salesforce.com  
Giacomo Del Vecchio - <giacomo.delvecchio@salesforce.com>  
