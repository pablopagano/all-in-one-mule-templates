# all-in-one-mule-templates
---
This repository contains all the templates projects as a form of  [git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) to facilitate the managment of the entire set.

These are the related projects used:

* [common-parent-pom](https://github.com/mulesoft-consulting/common-parent-pom)
* [mule-application-template](https://github.com/mulesoft-consulting/mule-application-template)
* [common-traits-lib](https://github.com/mulesoft-consulting/common-traits-lib)
* [dw-library-log-mapper](https://github.com/mulesoft-consulting/dw-library-log-mapper)
* [health-check-app](https://github.com/mulesoft-consulting/health-check-app)
* [dw-library-error-mapper](https://github.com/mulesoft-consulting/dw-library-error-mapper)
*  [mule-application-template](https://github.com/mulesoft-consulting/dw-library-error-mapper)


## Deployment Script for Mule and RAML Projects

### Overview

A tipical usage scenario for these templates is to create branches for a specific usage or customer on each of them and upload them to Anypoint Exchange.
The **deploy_script.sh**  is designed to streamline the deployment process for Mule and RAML templates. It automates tasks such as creating local git branches, deploying Maven projects, and handling specific tasks for different project types (Maven, RAML API, RAML Fragment).

### Prerequisites

Before using the script, ensure that the following prerequisites are met:

- **Java Installation:** Java version 1.8 or higher is required.
- **Maven Installation:** Maven version 3.9.5 or higher is required.
- **Git:** Git should be installed on the system.
- **bash:** bash should be installed on your system
- **jq:** jq utility must be installed on your system

### Usage

1. Ensure all the git submodules are updated and at the right version:

   ```
    git pull --recurse-submodules
   ```

2. (Optional) Configure the file (`deploy_config.json`) according to your project structure.

3. Execute the deployment script:

   ```bash
   ./deploy_script.sh <control_plane> <customer_name> <organization_id> <connected_app_id> <connected_app_secret>
   ```

   Replace the placeholder values with your actual input.
   This is a description of the parameters:

    | Parameter             | Description                                    |
    |-----------------------|------------------------------------------------|
    | `control_plane`       | A string specifying the control plane, which can be "eu" or "us". |
    | `customer_name`       | A string representing the customer name.        |
    | `organization_id`     | A string representing the organization ID.      |
    | `connected_app_id`    | A string representing the connected app ID.     |
    | `connected_app_secret`| A string representing the connected app secret. |

### Script Features

- **Java and Maven Version Checks:** The script checks whether the required versions of Java and Maven are installed.

- **Project Type Support:** The script supports different project types, including Maven projects, RAML API projects, and RAML Fragment projects.

- **Placeholder Replacement:** The script replaces the `GROUP_ID` placeholder in the `pom.xml`, `api.raml`, and `exchange.json` files.

- **Git Branch Creation:** The script creates a local git branch for each project.

- **Maven Deployment:** For Maven projects, the script executes the `mvn clean deploy` command. For RAML API projects, it additionally renames directories within `exchange_modules` and runs the `designcenter:project:create` command.

### Customization

- **Project Configuration:** Update the `deploy_config.json` file to include your specific project names and types.

- **Command Customization:** Modify the script to include additional commands or customize existing commands based on your project requirements.

## Authors

Contributors names and contact info

Marco Iarussi - miarussi@salesforce.com  
Patryk Sobczak - patryk.sobczak@salesforce.com  
Giacomo Del Vecchio - <giacomo.delvecchio@salesforce.com>  