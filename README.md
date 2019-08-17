# Spring CMS Generator

[![Open Source Love](https://badges.frapsoft.com/os/v1/open-source.svg?v=103)](https://github.com/ellerbrock/open-source-badges/) [![MIT Licence](https://badges.frapsoft.com/os/mit/mit.svg?v=103)](https://opensource.org/licenses/mit-license.php) [![Bash Shell](https://badges.frapsoft.com/bash/v1/bash.png?v=103)](https://github.com/ellerbrock/open-source-badges/) [![written-in-shell-script](https://img.shields.io/badge/</>-Shell%20Script-<COLOR>.svg)](https://shields.io/) [![current-version](https://img.shields.io/badge/version-1.1.0-blue.svg)](https://shields.io/) [![native-support](https://img.shields.io/badge/native--support-Linux%20%7C%20MacOS-lightgrey.svg)](https://shields.io/)

Spring Controller Model Service Generator is a easy to use Command Line Based code generator tool that handles most of the initial heavy-lighting for you when productivity is at essence. **Inspired from loopback.**

# Spring-CMS-Generator.sh

A simple cli based Spring Boot code generator that creates required along with importing adequate imports / dependencies. Also automatically @Autowires them as per the relations. Along with the freedom of setting custom directories.

After pulling the script make sure to provide adequate permissions

    sudo chmod +x ~/Desktop/spring-CMS-Generator.sh

This script is directory-agnostic. Open terminal in your project directory and call the script using:

    root@user ~/Documents/Spring/CMS-Project $ ~/Desktop/spring-CMS-Generator.sh

### CMS (Controller Model Service) Generation

In the Spring Framework there are basically 3 main components RestController, Models and Services that handles most of the inner-working so now you can automatically create these 3 files.

    ~/Desktop/spring-CMS-Generator.sh cms User

Using this command which automatically creates UserController, User, UserService files along with all the imports and needed Auto-wiring among them. You can create any kind of combinations with these 3 keywords c, m, s like you can have create only Service and Model using **ms** etc. and the necessary Auto-wiring and file imports are handled.

## Extra Flags in Controller Component

- **--need-sample**

  For controller we have a seperate flag that auto-generates certain code-snippets that is widely used in controller like generating **GET, POST, PUT, DELETE request mapping** along with description on how to **fetch data via Request Body, PathVariable, RequestParam** or **RequestHeader.**

        ~/Desktop/spring-CMS-Generator.sh m User --need-sample

## Extra Flags in Model Component

- **--import-sql**

  For model we have a seperate flag that auto-generates commented insert sql statments as per the `property Name` and `data Type` that is being passed while generation into import.sql for both main and test environments.

        ~/Desktop/spring-CMS-Generator.sh m User --import-sql

  - **-times**

    `--import-sql` flag has an extension flag `-times` we will replicate the number of times the insert statement will be created in import.sql. All the insert statement will be under multiLine comment

          ~/Desktop/spring-CMS-Generator.sh m User --import-sql -times=5

    The above statement will create insert statement for `User` entity 5 times in import.sql

### Extra Features in Model component

If you have **m** key the script prompts you to enter **propertyName** along with questions of **dataType, nullable and unique status** which after selecting so will auto generate Model file with code. Also after creation of Model, it's subsequent **Repository** file will be created.

##### Now you can add Relations from 1 Entity to another

When you are using `m` flag after the creation of properties to the entity file you will prompted to define any relations that this entity hold. They are basically 4 relations that can be defined:

- **M21**

  This will create @ManyToOne Relation in this entity file and on the terminal generates the code-snippet for @OneToMany that has to added in the related Model's file.

- **12M**

  This will create @OneToMany Relation in this entity file and on the terminal generates the code-snippet for @ManyToOne that has to added in the related Model's file.

- **121P**

  In the Case of OneToOne Mapping there is a Parent Entity and a Child Entity. It relies on the logic of that without Parent child wouldn't be possible.

  This will create @OneToOne Relation in this parent entity file and on the terminal generates the code-snippet for @OneToOne that has to added in the child Model's file.

- **121C**

  This will create @OneToOne Relation in this child entity file and on the terminal generates the code-snippet for @OneToOne that has to added in the parent Model's file.

## Make Sure

> If you are using some IDE like Eclipse, STS or Intellij after running the script make sure to **Refresh** the project so that the IDE can link all the new files added to the system.

## --pluginCodeGen

This is a new feature added in the script unlike from that seen in loopback. This flag when added right after invocation of the script along with few built-in commands autogenerates pre-defined controllers and injects subsequent properties along with maven dependencies.

    ~/Desktop/spring-CMS-generator.sh --pluginCodeGen oauth2 mysql multiLang-support freemaker sonar internationalization swagger

Currently supported plugins for - -pluginCodeGen

- **oauth2**

  On passing this arguement to the flag, it would automatically add the plugins, set the needed properties to the properties file. Also adds needed security files to your project. Also generates some Controller that highlights some of the essentials methods like `Custom Route Mapping, TokenEnhancer, Logout Functionality`. Along with a `User Model and Repo files` that is needed.

- **oauth2-db**

  Same as the oauth2 but has `improved functionality of writing tokens into the database provided`, also `prompts you to add some sql scripts into the import.sql file` with client credentials as **admin admin123** that would needed for it to perform.

- **mysql**

  On passing this argument to the flag, it would automatically add maven dependencies along with **h2** dependency for test cases. Injects some properties lines into your `application.properties` file

- **freemaker**

  Easy to use and powerful template engine for spring, as being provided here. After passing the argument, it would add the maven dependencies, needed properties and also a `sampleController` and `sample.ftl` files to provide user on how to work with this library.

- **multiLang-support**

  On entering this flag, automatically the entire spring boot application will updated to `support multiple languages` to an extent using `some pre-defined code snippets that would added to resources, model and example controller and service` that works seamlessly.

- **internationalization**

  On entering this flag, it automatically generates configuration files inside the spring boot project which will make the system automatically support localization of messages based on the value passed in `Accept-Language` header per request along with a sample controller to demostrate how to use it. Along with Localization of javax.hibernate.validator messages.

- **sonar**

  Adds `sonarqube plugin` to pom.xml and adds sonar.properties file into your project that would be sufficient for the sonarqube component to `generate analytics for your project.` Added sonar.exclusions and lombok generated code exclusions with wiremock dependency for mocking APIs.

- **swagger**

  Adds `swagger dependency` to pom.xml and injects SwaggerConfig file with all the basic properties in place. Along with sample controller to show all the Annotations and how to use how.

## Danger

At a time you can either use --pluginCodeGen or cms as the first arguement for the script. If both are passed in the script at the same time, it could lead to unwanted results.

## Aspect Generator

Create your Aspects as easy as calling a script

    ~/Desktop/spring-CMS-Generator.sh a EmailChecker

Then the script will automatically ask you some questions that will then generate the needed code snippets that can used anywhere in the project.

# Custom Directory

- In case if you want to generate `controller` in custom path rather than pre-defined location you can use `--c-folder=.custom.controller`
- In case if you want to generate `service` in custom path rather than pre-defined location you can use `--s-folder=.custom.service`
- In case if you want to generate `model` in custom path rather than pre-defined location you can use `--c-folder=.custom.model`
- In case if you want to generate `repository` files in custom path rather than pre-defined location you can use `--c-folder=.custom.repository`
- In case if you want to generate `aspect` in custom path rather than pre-defined location you can use `--c-folder=.custom.aspect`

  ~/Desktop/spring-CMS-Generator.sh cmsa --c-folder=.custom. --m-folder=.tables --r-folder=.tables.repo --s-folder=.custom.web.util --a-folder=.utility.aspect

## Rules for Custom Directory

- In first flag passed is only of controller `c` and `--s-folder` is passed with value no changes will occur.
- folder flag value should always start with `.`
- If folder flag value ends and starts with `.` like `.custom.` then generated directory is `/custom/controller` as in pre-defined controller directory for c flag.
- If folder flag value starts with `.` and doesn't end with `.` like `.tables` then generated directory is `/tables`

# Further Developments

- Creating .bat file for Windows so alternatively you can use git bash to execute bash script in Windows
- In the case of Aspect type as PARAMETER @Around statement will be replaced with another line
