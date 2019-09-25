#!/bin/bash

working_dir=$(find src/main/java -name *Application.java | sed 's|/[^/]*$||' | head -n 1)
#working_test_dir=$(find src/test/java -name *ApplicationTests.java | sed 's|/[^/]*$||' | head -n 1)
working_test_dir="${working_dir//main/test}"
package_name=$(echo $working_dir | cut -c 15- | tr "/" .)

function javaVariable() {
	local smallCase=$(echo "$1" | sed 's/^./\L&\E/')
	echo "$smallCase"
}

function dbVariable() {
	local smallCaseWithUnderscore=$(echo "$1" | sed -e 's/\([^[:blank:]]\)\([[:upper:]]\)/\1_\2/g' | tr '[:upper:]' '[:lower:]')

	echo "$smallCaseWithUnderscore"
}

function importSqlFormatter() {
	local sqlType="$(cut -d':' -f2 <<<"${1::-1}")"
	if [[ "$sqlType" == String ]]; then echo "'$1',"; else echo "$1,"; fi
}

folder_values() {
	package_ext=""
	package_ext=$3
	for flag in $2; do
		if [[ $flag == $1* ]]; then
			package_intent_ext=${flag:11}
			if [[ "${package_intent_ext:0:1}" == "." ]]; then
				[ "${package_intent_ext: -1}" == "." ] && package_ext=${package_intent_ext%?}${package_ext} || package_ext=${package_intent_ext}
			else
				echo -e "\033[1;31mfolder name must start with ."
				exit 1
			fi
			break
		fi
	done
}

fileName=$(echo "$2" | sed 's/^./\U&\E/')
smallCase=$(javaVariable $fileName)
smallCaseWithUnderscore=$(dbVariable $smallCase)

mkdir -p $working_test_dir/controller

if [[ $1 == *--pluginCodeGen* ]]; then
	nameLine=$(grep -n "<name>" pom.xml | cut -d ':' -f 1)

	projName=$(sed -e "${nameLine}q;d" pom.xml | sed -e 's/<[^>]*>//g' | sed "s/^[ \t]*//")

	projNameInSmall=$(echo "$projName" | tr '[:upper:]' '[:lower:]')

	newLine=\\n
	packagingType=$(sed -n -e 's/.*<packaging>\(.*\)<\/packaging>.*/\1/p' pom.xml)
	[ -z "$packagingType" ] && packagingType=war

	sed -i '/<\/project>/d' pom.xml
	sed -i '/<finalName>/,/<\/packaging>/c<\/build>' pom.xml

	sed -i "s/<\/build>/		<finalName>${projNameInSmall}<\/finalName>${newLine}\
	<\/build>${newLine}\
	<packaging>${packagingType}<\/packaging>${newLine}\
<\/project>/g" pom.xml

	if [ "$packagingType" == "war" ]; then
		printf '\e[1;35m%-6s\e[m' "For war file, value in <finalName> is the context-path
		"
		printf '\e[1;36m%-6s\e[m' "Also make sure you extends SpringBootServletInitializer
		"
		printf '\e[1;36m%-6s\e[m' "spring.datasource.jndi-name in application.properties is necessary
"
	elif [ "$packagingType" == "jar" ]; then
		printf '\e[1;35m%-6s\e[m' "For jar file, server.servlet.context-path is needed along 
		with <finalName>
		"
		printf '\e[1;36m%-6s\e[m' "instance's database credentials are needed if application.yml
		is not added in the instance.
"
	fi

	if [[ $* == *internationalization* ]]; then
		mkdir -p $working_dir/{configuration,controller}
		mkdir -p src/main/resources/messages
		echo "package "$package_name".configuration;

import java.util.Locale;

import javax.servlet.http.HttpServletRequest;
import java.text.MessageFormat;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.context.support.ResourceBundleMessageSource;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import com.google.common.base.Strings;

@Component
public class Translator {

   private static ResourceBundleMessageSource messageSource;

   @Autowired
   Translator(ResourceBundleMessageSource messageSource) {
      Translator.messageSource = messageSource;
   }

   public static Languages getSelectedLang() {
	   HttpServletRequest request = ((ServletRequestAttributes) RequestContextHolder.getRequestAttributes()).getRequest();
	   String headerLang = request.getHeader(\"Accept-Language\");
		if (Strings.isNullOrEmpty(headerLang)) {
			return Languages.valueOf(\"en\");
		} else {
			return Languages.valueOf(headerLang.split(\"-\")[0]);	
		}
   }

   public static String toLocale(String msgCode) {
      Locale locale = LocaleContextHolder.getLocale();
      return messageSource.getMessage(msgCode, null, locale);
   }

   public static String toLocale(String msgCode, Object... args) {
      Locale locale = LocaleContextHolder.getLocale();
      return MessageFormat.format(messageSource.getMessage(msgCode, null, locale), args);
   }

   public static String toLocale(String msgCode, String langCode) {
      ResourceBundle bundle = ResourceBundle.getBundle(\"messages/messages\", Locale.forLanguageTag(langCode));
      return bundle.getString(msgCode);
   }

    public static String toLocale(String msgCode, String langCode, Object... args) {
      ResourceBundle bundle = ResourceBundle.getBundle(\"messages/messages\", Locale.forLanguageTag(langCode));
      return MessageFormat.format(bundle.getString(msgCode), args);
   }
}" >"$working_dir/configuration/Translator.java"

		echo "package "$package_name".configuration;

import java.util.Locale;

import javax.servlet.http.HttpServletRequest;

import org.springframework.context.MessageSource;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.support.ReloadableResourceBundleMessageSource;
import org.springframework.context.support.ResourceBundleMessageSource;
import org.springframework.validation.beanvalidation.LocalValidatorFactoryBean;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;
import org.springframework.web.servlet.i18n.AcceptHeaderLocaleResolver;

import com.google.common.base.Strings;

@Configuration
public class CustomLocaleResolver 
             extends AcceptHeaderLocaleResolver 
             implements WebMvcConfigurer {

   @Bean
   public ResourceBundleMessageSource resourceBundleMessageSource() {
      ResourceBundleMessageSource rs = new ResourceBundleMessageSource();
      rs.setBasename(\"messages/messages\");
      rs.setDefaultEncoding(\"UTF-8\");
      rs.setUseCodeAsDefaultMessage(true);
      return rs;
   }
   
	@Override
	public Locale resolveLocale(HttpServletRequest request) {
		String headerLang = request.getHeader(\"Accept-Language\");
		if (Strings.isNullOrEmpty(headerLang)) {
			return Locale.getDefault();
		} else {
			String[] values = headerLang.split(\"-\");
			switch (values.length) {
			case 1:
				return new Locale(values[0]);

			case 2:
				return new Locale(values[0], values[1]);

			case 3:
				return new Locale(values[0], values[1], values[2]);

			default:
				return new Locale(\"en\");
			}
		}
	}

   //Localization for javax.hibernate.validator
   @Bean
   public MessageSource messageSource() {
       ReloadableResourceBundleMessageSource messageSource = new ReloadableResourceBundleMessageSource();
       messageSource.setBasename(\"classpath:messages/messages\");
       messageSource.setDefaultEncoding(\"UTF-8\");
       return messageSource;
   }

   @Bean @Override
   public LocalValidatorFactoryBean getValidator() {
       LocalValidatorFactoryBean bean = new LocalValidatorFactoryBean();
       bean.setValidationMessageSource(messageSource());
       return bean;
   }
}" >"$working_dir/configuration/CustomLocaleResolver.java"
		echo "hello=Hello there {0}
lang_code_unsupported=Passed LangCode is currently unsupported" >src/main/resources/messages/messages_en.properties

		echo "hello=Hallo {0}
lang_code_unsupported=Passed LangCode ist derzeit nicht unterstützt." >src/main/resources/messages/messages_de.properties

		echo "package $package_name.controller;

import javax.validation.constraints.Pattern;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.validation.annotation.Validated;

import $package_name.configuration.Translator;

@RestController
@Validated
public class InternationalizationController {
	
	@GetMapping(\"/internationalization\")
	public ResponseEntity<String> internationalMessage(
			@RequestHeader(value=\"Accept-Language\", required=true) @Pattern(regexp=\"en|de\",message=\"{lang_code_unsupported}\")String acceptableLang){

		return ResponseEntity.ok(\"Selected Language code is \"+Translator.getSelectedLang().getValue()+\": \"+Translator.toLocale(\"hello\", \"User\")+\": \"+Translator.toLocale(\"hello\", \"de\", \"User\"));
	}
}" >$working_dir/controller/InternationalizationController.java
		printf '\e[1;35m%-6s\e[m' "	Created Translator and CustomLocaleResolver Components for Spring to support Internationalization.
	Added messages folder with localized text and InternationalizationController for sample implementation. Access subLocale by creating en_US.properties and hitting en-US in Accept-Language header"
	fi

	if [[ $* == *sonar* ]]; then
		sed -i 's/	<dependencies>/	<dependencies>\
		<!-- Dependencies needed for wiremock -->\
		<dependency>\
			<groupId>com.github.tomakehurst<\/groupId>\
			<artifactId>wiremock<\/artifactId>\
			<version>2.23.2<\/version>\
			<scope>test<\/scope>\
		<\/dependency>\
		/g' pom.xml
		sed -i 's/		<\/plugin>/		<\/plugin>\
			<!-- plugin and execution goals needed for running sonar -->\
			<plugin>\
				<groupId>org.apache.maven.plugins<\/groupId>\
				<artifactId>maven-surefire-plugin<\/artifactId>\
			<\/plugin>\
			<plugin>\
				<groupId>org.jacoco<\/groupId>\
				<artifactId>jacoco-maven-plugin<\/artifactId>\
				<version>0.8.0<\/version>\
				<executions>\
					<execution>\
						<id>default-prepare-agent<\/id>\
						<goals>\
							<goal>prepare-agent<\/goal>\
						<\/goals>\
					<\/execution>\
					<execution>\
						<id>default-report<\/id>\
						<phase>prepare-package<\/phase>\
						<goals>\
							<goal>report<\/goal>\
						<\/goals>\
					<\/execution>\
				<\/executions>\
			<\/plugin>/g' pom.xml

		packageInBrackets=$(echo "$package_name" | tr . "/")

		echo "sonar.projectKey=${projNameInSmall}-java
sonar.projectName=${projName}-Java
sonar.projectVersion=1.0
sonar.dynamicAnalysis=reuseReports
sonar.language=java
sonar.sourceEncoding=UTF-8
sonar.jacoco.reportPaths=target/jacoco.exec

sonar.tests=src/test/java
sonar.sources=src/main/java

sonar.exclusions=target/generated-sources/**, **/errors/**/* , **/security/**/*, **/configuration/**/*, **/exception/**/*

sonar.java.binaries=target/classes
sonar.java.test.binaries=./target/test-classes/${packageInBrackets}" >sonar-project.properties

		echo "lombok.addLombokGeneratedAnnotation = true" >lombok.config

		printf '\e[1;35m%-6s\e[m' "	Updated pom.xml with required dependency and plugins for sonar.
	Added sonar-project.properties with required context and lombok.config file to ignore lombok generated code
"
	fi

	if [[ $* == *swagger* ]]; then
		mkdir -p $working_dir/{configuration,controller}

		sed -i 's/	<dependencies>/	<dependencies>\
		<!-- SpringFox (Swagger) Documentation-->\
		<dependency>\
			<groupId>io.springfox<\/groupId>\
			<artifactId>springfox-swagger-ui<\/artifactId>\
			<version>2.9.2<\/version>\
		<\/dependency>\
		<dependency>\
			<groupId>io.springfox<\/groupId>\
			<artifactId>springfox-swagger2<\/artifactId>\
			<version>2.9.2<\/version>\
		<\/dependency>\
		/g' pom.xml
		echo "package $package_name.configuration;
		
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

import springfox.documentation.builders.ApiInfoBuilder;
import springfox.documentation.builders.PathSelectors;
import springfox.documentation.builders.RequestHandlerSelectors;
import springfox.documentation.service.ApiInfo;
import springfox.documentation.spi.DocumentationType;
import springfox.documentation.spring.web.plugins.Docket;

@Profile(\"!demo & !test\")
@Configuration
public class SwaggerConfig
{
	private static final Set<String> DEFAULT_PRODUCES_AND_CONSUMES = new HashSet<>(Arrays.asList(\"application/json\"));
	
	@Bean
    public Docket productApi() {
        return new Docket(DocumentationType.SWAGGER_2)
        		.useDefaultResponseMessages(false)
        		.directModelSubstitute(Object.class, java.lang.Void.class)
        		.produces(DEFAULT_PRODUCES_AND_CONSUMES)
        		.select().apis(RequestHandlerSelectors
						.basePackage(\"$package_name.controller\"))
				.paths(PathSelectors.regex(\"/.*\")).build().apiInfo(apiEndPointsInfo());
    }
        
//    @Bean
//    UiConfigurationBuilder uiConfiguration() {
//        return UiConfigurationBuilder.builder().supportedSubmitMethods(new String[]{\"get\"});
//    }
    
    private ApiInfo apiEndPointsInfo() 
	{
		return new ApiInfoBuilder().title(\"Spring Swagger Project\")
				.description(\"Spring Boot Swagger Project with REST API Development\")
				.version(\"1.0.0\")
				.build();
	}
}" >"$working_dir/configuration/SwaggerConfig.java"

		echo "package $package_name.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.annotations.ApiImplicitParam;
import io.swagger.annotations.ApiImplicitParams;
import io.swagger.annotations.ApiOperation;
import io.swagger.annotations.ApiResponse;
import io.swagger.annotations.ApiResponses;

@RestController
public class SwaggerController {

	@ApiOperation(value = \"Add User Data to db\", notes =  
			\"This API is used to save all the data regarding user into the database\")
	@ApiResponses({
		@ApiResponse(code = 200, message = \"Successfully done\"),   
		@ApiResponse(code = 401, message = \"Unauthorized\"),   	        
		@ApiResponse(code = 500, message = \"Some Server Issue\"),
	})
	@ApiImplicitParams({
		@ApiImplicitParam(name = \"Authorization\", value = \"Access Token eg:- Bearer {access_token}\", required = true, allowEmptyValue = false, paramType = \"header\", 
				dataTypeClass = String.class,example = \"Bearer access_token\"), 
		@ApiImplicitParam(name = \"userData\", value = \"Send this data in the request and the all fields are mandatory and the type is string \n {\n\" + 
				\"	\\\"email\\\" : \\\"{emailaddress}\\\",\n\" +
				\"	\\\"firstName\\\" : \\\"{firstName}\\\",\n\" +
				\"	\\\"lastName\\\" : \\\"{lastName}\\\",\n\" +
				\"	\\\"password\\\" : \\\"{password}\\\",\n\" +
				\"	\\\"phoneNumber\\\" : \\\"{phoneNumber}\\\",\n\" +
				\"}\", required = true, allowEmptyValue = false, paramType = \"body\", 
				dataTypeClass = Object.class)
	})
	@PostMapping(\"/users\")
	public ResponseEntity<Void> addUserInfo(@RequestBody String userData){
		//some user based operation
		return ResponseEntity.ok().build();
	}
}" >"$working_dir/controller/SwaggerController.java"

		printf '\e[1;35m%-6s\e[m' "	Updated pom.xml with required dependency for swagger.
	Added SwaggerConfig with required context and SwaggerController for sample implementation"
	fi

	if [[ $* == *multiLang-support* ]]; then
		mkdir -p src/main/resources/languageTranslations
		echo "{
		\"hello\": \"Hello\"
		}" >src/main/resources/languageTranslations/en.json

		echo "{
		\"hello\": \"Hallo\"
		}" >src/main/resources/languageTranslations/de.json

		sed -i 's/	<dependencies>/	<dependencies>\
		<!-- Dependencies needed for multiLang-support -->\
		<dependency>\
			<groupId>com.jayway.jsonpath<\/groupId>\
			<artifactId>json-path<\/artifactId>\
		<\/dependency>\
		<dependency>\
			<groupId>org.projectlombok<\/groupId>\
			<artifactId>lombok<\/artifactId>\
			<optional>true<\/optional>\
		<\/dependency>\
    /g' pom.xml

		mkdir -p $working_dir/{controller,service,model,repository,aspect}

		echo "package "$package_name".model;

import java.util.List;

import javax.persistence.CascadeType;
import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.FetchType;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.OneToMany;
import javax.persistence.Table;

import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
@Entity
@Table(name=\"language_translations\")
public class LanguageTranslations 
{
	@Id
	@GeneratedValue(strategy=GenerationType.IDENTITY)
	@Column(name=\"language_translations_id\", nullable = false)
	private long languageTranslationsId;
	
	@Column(name=\"language_name\", nullable = false)
	private String languageName;

// Any model that requires langCode in it's model will have this line 
//	@ManyToOne
//	@JoinColumn(name=\"language_translations_id\",referencedColumnName=\"language_translations_id\",nullable=false)
//	private LanguageTranslations languageTranslations;
	
//	and subsequently this file will contain
// it's equivalent @OneToMany mapping
}" >"$working_dir/model/LanguageTranslations.java"

		echo "package "$package_name".repository;

import org.springframework.data.repository.CrudRepository;
import java.util.Optional;
import "$package_name.model.LanguageTranslations";

public interface LanguageTranslationsRepository extends CrudRepository<LanguageTranslations, Long> 
{
	Optional<LanguageTranslations> findByLanguageName(String languageName);
}" >"$working_dir/repository/LanguageTranslationsRepository.java"

		echo "package "$package_name".aspect;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface LanguageChecker {}
" >"$working_dir/aspect/LanguageChecker.java"

		echo "package "$package_name".aspect;

import java.lang.annotation.Annotation;
import java.lang.reflect.Method;

import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.reflect.MethodSignature;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestHeader;

import "$package_name".repository.LanguageTranslationsRepository;
import "$package_name".service.LanguageTranslationService;

public class LanguageCheckerAspect {

	@Autowired
	private LanguageTranslationsRepository languageTranslationsRepository;
	
	@Autowired
	private LanguageTranslationService languageTranslationService;
	
	@Around(\"@annotation(com.calf.care.aspect.LanguageChecker)\")
	public Object LanguageCheckerAndDataFeederAspectImpl(ProceedingJoinPoint joinPoint) throws Throwable {
		String locale = (String)joinPoint.getArgs()[fetchLocationOfRequestHeader(joinPoint, \"Accept-Language\")];
		
		if(languageTranslationsRepository.findByLanguageName(locale).isPresent())
		{
			return joinPoint.proceed();
		}
		return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).build();
	}
	public static int fetchLocationOfRequestHeader(ProceedingJoinPoint joinPoint, String annotationValue)
	{
		 Object[] args = joinPoint.getArgs();
	     MethodSignature methodSignature = (MethodSignature) joinPoint.getStaticPart().getSignature();
	     Method method = methodSignature.getMethod();
	     Annotation[][] parameterAnnotations = method.getParameterAnnotations();
	     assert args.length == parameterAnnotations.length;
	     for (int argIndex = 0; argIndex < args.length; argIndex++) {
	         for (Annotation annotation : parameterAnnotations[argIndex]) {
	             if (!(annotation instanceof RequestHeader))
	                 continue;
	             RequestHeader requestHeader = (RequestHeader) annotation;
	             if (! annotationValue.equals(requestHeader.value()))
	                 continue;
	             return argIndex;
	         }
	     }
	     return -1;
	}
}" >"$working_dir/aspect/LanguageCheckerAspect.java"

		echo "package "$package_name".controller;

import java.util.HashMap;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;
import com.jayway.jsonpath.JsonPath;

import "$package_name".aspect.LanguageChecker;
import "$package_name".service.LanguageTranslationService;
		
@RestController
public class LanguageTranslationController 
{
	@Autowired
	private LanguageTranslationService languageTranslationService;
	
	@LanguageChecker
	@GetMapping(\"/langCode\")
	public ResponseEntity<String> getLangCodeAndJson(@RequestHeader(\"Accept-Language\")String locale)
	{
		String localeJSONData = languageTranslationService.getTranslationLanguageData(locale);
		
		return ResponseEntity.status(HttpStatus.ACCEPTED).body(\"Requested Locale is: \" + locale + \" and Translation is: \" + JsonPath.read(localeJSONData, \"$.hello\"));
	}
}" >"$working_dir/controller/LanguageTranslationController.java"

		echo "package "$package_name".service;

import java.io.File;
import java.nio.file.Files;

import org.springframework.core.io.ClassPathResource;
import org.springframework.util.StreamUtils;
import java.nio.charset.Charset;
import org.springframework.stereotype.Service;

@Service
public class LanguageTranslationService 
{
	String os = System.getProperty(\"os.name\").toLowerCase().indexOf(\"win\") >= 0 ? \"\\\\\": \"/\";
	
	public String getTranslationLanguageData(String locale)
	{
		try
		{
			return StreamUtils.copyToString(
                new ClassPathResource(\"languageTranslations\"+os+locale+\".json\").getInputStream(),
                   Charset.defaultCharset();
		}
		catch (Exception e) 
		{
			e.printStackTrace();
			return null;
		}		
	}
}" >"$working_dir/service/LanguageTranslationService.java"
		printf '\e[1;31m%-6s\e[m' "Generated en, de json files
Updated pom.xml with required imports for multiLang support
Generated LanguageTranslations model and it's Repository method
LanguageChecker Aspect file
Sample Implementation of Multi-Lang using LanguageTranslationController and LanguageTranslationService
Added mysql lines to this file in both test and main folders-> import.sql
"

		for i in main test; do

			echo "
" >>src/$i/resources/import.sql

			sed -i -e '$a\
INSERT INTO language_translations(language_name)VALUES(\x27en\x27);\
INSERT INTO language_translations(language_name)VALUES(\x27de\x27);' src/$i/resources/import.sql
		done
	fi
	if [[ $* == *freemaker* ]]; then
		mkdir -p $working_dir/controller
		sed -i 's/	<dependencies>/	<dependencies>\
	<!-- Dependencies needed for supporting freemaker -->\
		<dependency>\
           <groupId>org.springframework.boot<\/groupId>\
           <artifactId>spring-boot-starter-freemarker<\/artifactId>\
       <\/dependency>\
       <dependency>\
  		  	<groupId>org.apache.poi<\/groupId>\
    	  	<artifactId>poi<\/artifactId>\
    	  	<version>3.10-FINAL<\/version>\
		<\/dependency>\
		/g' pom.xml

		echo "
" >>src/main/resources/application.properties
		sed -i '1i\
			 \
spring.freemarker.template-loader-path: classpath:/static\
spring.freemarker.suffix: .ftl' src/main/resources/application.properties

		echo "<#import \"/spring.ftl\" as spring />

<!DOCTYPE html>
<html lang=\"en\">
    <head>
        <meta charset=\"UTF-8\"> 
    </head>
    
    <body align=\"center\">
    
    	<@spring.bind \"user\"/>
		<@spring.bind \"logo\"/>

    	<h2>Hello there to \${user}</h2>
		<!-- <img src=\"\${img}\" /> -->
    </body>
</html>" >src/main/resources/static/sample.ftl

		echo "package "$package_name".controller;

import java.io.IOException;
import org.apache.commons.codec.binary.Base64;

import org.apache.poi.util.IOUtils;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class FreeMakerController 
{
	//You may not see this endpoint working on the browser if you
	//have oauth2 implemented. For that go to ResourceServerWebSecurityConfigurer
	//in security directory and add this endpoint which will close the authentication
	//for this endpoint. 
	@GetMapping(\"/sample-freemaker\")
    public String webTemplate(Model model) throws IOException {
		model.addAttribute(\"user\", \"Yo-Bro!!\");
        return \"sample\";
    }

	//For Images
    public String imgLogo() throws IOException{
		byte[] imgBytes = IOUtils.toByteArray(new ClassPathResource(\"imageName-present-resources-folder.png\").getInputStream());
		byte[] imgBytesAsBase64 = Base64.encodeBase64(imgBytes);
		//Just like above 
		//model.addAttribute(\"img\", imgLogo());
		return \"data:image/png;base64,\" + new String(imgBytesAsBase64);
	}
}" >"$working_dir/controller/FreeMakerController.java"

		printf '\e[1;39m%-6s\e[m' "Updated pom.xml with required imports for freemaker
Added necessary lines to pom.xml
Added Sample Implementaion of the same using sample.ftl in resources/static folder and FreemakerController
"
	fi

	if [[ $* == *mysql* ]]; then

		sed -i 's/	<dependencies>/	<dependencies>\
	<!-- Dependencies needed for mysql -->\
		<dependency>\
			<groupId>com.h2database<\/groupId>\
			<artifactId>h2<\/artifactId>\
			<scope>test<\/scope>\
		<\/dependency>\
		<dependency>\
			<groupId>mysql<\/groupId>\
			<artifactId>mysql-connector-java<\/artifactId>\
			<scope>runtime<\/scope>\
		<\/dependency>\
		<dependency>\
			<groupId>org.springframework.boot<\/groupId>\
			<artifactId>spring-boot-starter-data-jpa<\/artifactId>\
		<\/dependency>\
		<dependency>\
			<groupId>org.projectlombok<\/groupId>\
			<artifactId>lombok<\/artifactId>\
			<optional>true<\/optional>\
		<\/dependency>\
		/g' pom.xml

		echo "
" >>src/main/resources/application.properties
		sed -i '1i\
spring.jpa.hibernate.ddl-auto=update\
\
\
#spring.datasource.jndi-name=java:comp/env/jdbc/*tomcat-jndi-name*\
\
#spring.jpa.show-sql=true\
#spring.jpa.properties.hibernate.format_sql=true\
\
spring.datasource.url=jdbc:mysql://localhost:3306/*someDBName*?createDatabaseIfNotExist=true&useSSL=false\
spring.datasource.username=root\
spring.datasource.password=root\
spring.jpa.properties.hibernate.dialect = org.hibernate.dialect.MySQL5Dialect\
server.servlet.context-path=/*someContextPath*\n' src/main/resources/application.properties

		mkdir -p src/test/resources

		echo "
" >>src/test/resources/application.properties

		sed -i '1i\
spring.jpa.hibernate.ddl-auto=create\
spring.datasource.url=jdbc:h2:mem:db;DB_CLOSE_ON_EXIT=FALSE\
spring.datasource.username=sa\
spring.datasource.password=sa\
spring.jpa.database-platform=org.hibernate.dialect.H2Dialect\
spring.h2.console.enabled=true\
spring.datasource.driverClassName=org.h2.Driver' src/test/resources/application.properties

		printf "Updated pom.xml with required imports for mysql functionality
Added necessary lines in application.properties in both main and test folders
"
		printf "\e[1;31mMake sure to update \e[46;5;12mtomcat-jndi-name and databaseName and someContextPath\e[0m \e[1;31min main/resources/app.properties file\e[0m
"
	fi

	if [[ $* == *oauth2* ]]; then
		mkdir -p $working_dir/{controller,model,repository,security}
		sed -i 's/	<dependencies>/	<dependencies>\
	<!-- Dependencies needed for OAuth2 -->\
		<dependency>\
			<groupId>org.springframework.boot<\/groupId>\
			<artifactId>spring-boot-starter-security<\/artifactId>\
		<\/dependency>\
		<dependency>\
			<groupId>org.springframework.security<\/groupId>\
			<artifactId>spring-security-test<\/artifactId>\
			<scope>test<\/scope>\
		<\/dependency>\
		<dependency>\
  		  <groupId>org.springframework.security.oauth<\/groupId>\
  		 	<artifactId>spring-security-oauth2<\/artifactId>\
   		 	<version>2.3.3.RELEASE<\/version>\
		<\/dependency>\
		/g' pom.xml

		echo "package "$package_name".controller;

import javax.servlet.http.HttpServletRequest;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.oauth2.provider.token.ConsumerTokenServices;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class OAuth2Controller {
	
	@Autowired
	private ConsumerTokenServices tokenServices;
	
	@Autowired
	private HttpServletRequest request;

	@PostMapping(\"/logout\")
    public ResponseEntity<Void> logout()
    {
       String authorization = request.getHeader(\"Authorization\");
       if (authorization != null && authorization.contains(\"Bearer\"))
       {
           String tokenId = authorization.substring(\"Bearer\".length()+1);
           tokenServices.revokeToken(tokenId);
       }      
       return ResponseEntity.ok(null);      
    }
}" >"$working_dir/controller/OAuth2Controller.java"

		echo "package "$package_name".repository;

import java.util.Optional;

import org.springframework.data.repository.CrudRepository;

import "$package_name".model.UserOAuth2;

public interface UserOAuth2Repository extends CrudRepository<UserOAuth2, Long> 
{
	Optional<UserOAuth2> findByEmail(String email);
}" >"$working_dir/repository/UserOAuth2Repository.java"
		echo "package "$package_name".model;

import java.util.ArrayList;
import java.util.Collection;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.Table;

import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import com.fasterxml.jackson.annotation.JsonIgnore;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@Entity
@Table(name=\"user_oauth2\")
public class UserOAuth2 implements UserDetails
{
	private static final long serialVersionUID = 8734450729169071352L;

	@Id
	@GeneratedValue(strategy=GenerationType.IDENTITY)
	@Column(name=\"user_id\", nullable = false)
	private long userId;
	
	@Column(name=\"name\", nullable = false)
	private String name;
	
	@Column(name = \"email\", nullable = false, unique = true)
	private String email;
		
	@Column(name=\"password\", nullable = false)
	private String password;		
	
	@Column(name = \"ENABLED\")
	private boolean enabled;

	@JsonIgnore
	@Override
	public Collection<? extends GrantedAuthority> getAuthorities() 
	{
		return new ArrayList<>();
	}
	
	@JsonIgnore
	@Override
	public String getUsername() {
		return email;
	}

	@Override
	public String getPassword() {
		return null;
	}

	@JsonIgnore
	@Override
	public boolean isAccountNonExpired() {
		return true;
	}

	@JsonIgnore
	public void setEnabled(boolean enabled) {
		this.enabled = enabled;
	}

	@JsonIgnore
	@Override
	public boolean isAccountNonLocked() {
		return true;
	}

	@JsonIgnore
	@Override
	public boolean isCredentialsNonExpired() {
		return true;
	}

	@JsonIgnore
	@Override
	public boolean isEnabled() {
		return enabled;
	}
}" >"$working_dir/model/UserOAuth2.java"

		echo "package "$package_name".security;

import java.io.IOException;

import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class CorsFilter implements Filter
{
    @Override
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
            throws IOException, ServletException {
        final HttpServletResponse response = (HttpServletResponse) res;
        response.setHeader(\"Access-Control-Allow-Origin\", \"*\");
        response.setHeader(\"Access-Control-Allow-Methods\", \"PATCH, POST, PUT, GET, OPTIONS, DELETE\");
        response.setHeader(\"Access-Control-Allow-Headers\", \"Authorization, Content-Type\");
        response.setHeader(\"Access-Control-Max-Age\", \"3600\");
        if (\"OPTIONS\".equalsIgnoreCase(((HttpServletRequest) req).getMethod())) {
            response.setStatus(HttpServletResponse.SC_OK);
        } else {
            chain.doFilter(req, res);
        }
    }

    @Override
    public void destroy() {
    }

    @Override
    public void init(FilterConfig config) {
    }
}" >"$working_dir/security/CorsFilter.java"

		oauth2Config="package "$package_name".security;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import javax.sql.DataSource;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Lazy;
import org.springframework.context.annotation.Primary;
import org.springframework.core.annotation.Order;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.builders.AuthenticationManagerBuilder;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configuration.WebSecurityConfigurerAdapter;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.factory.PasswordEncoderFactories;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.config.annotation.configurers.ClientDetailsServiceConfigurer;
import org.springframework.security.oauth2.config.annotation.web.configuration.AuthorizationServerConfigurerAdapter;
import org.springframework.security.oauth2.config.annotation.web.configuration.EnableAuthorizationServer;
import org.springframework.security.oauth2.config.annotation.web.configuration.EnableResourceServer;
import org.springframework.security.oauth2.config.annotation.web.configurers.AuthorizationServerEndpointsConfigurer;
import org.springframework.security.oauth2.config.annotation.web.configurers.AuthorizationServerSecurityConfigurer;
import org.springframework.security.oauth2.provider.token.DefaultTokenServices;
import org.springframework.security.oauth2.provider.token.TokenStore;
import org.springframework.security.oauth2.provider.token.store.InMemoryTokenStore;
import org.springframework.security.oauth2.provider.token.store.JdbcTokenStore;
import org.springframework.http.HttpMethod;

@Configuration
@Order(2)
@EnableResourceServer
@EnableAuthorizationServer
public class OAuth2Config extends AuthorizationServerConfigurerAdapter
{"

		if [[ $* == *oauth2-db* ]]; then
			oauth2Config+="    	 
	@Lazy
	@Autowired
	@Qualifier(\"userDetailsService\")
	private UserDetailsService userDetailsService;

	@Autowired
	@Qualifier(\"authenticationManagerBean\")
	private AuthenticationManager authenticationManager;		   
    
    @Autowired
    private DataSource dataSource;		
	
    @Bean
    public PasswordEncoder passwordEncoder() {
        return PasswordEncoderFactories.createDelegatingPasswordEncoder();
    }
	
    @Override
    public void configure(final AuthorizationServerSecurityConfigurer oauthServer) {
        oauthServer.tokenKeyAccess(\"permitAll()\")
                .checkTokenAccess(\"isAuthenticated()\");
    }

    @Override
    public void configure(final ClientDetailsServiceConfigurer clients) throws Exception {
        clients.jdbc(dataSource);
    }

////////////////////////////////////////////////////////////////
//	  If there is a customPath Mapping or Custom Tokenizer required use the below configure method
	@Bean
   public CustomTokenConverter customTokenEnhancer() {
       return new CustomTokenConverter();
   } 

	//Changes as per the CustomTokener as below
	public void configure(AuthorizationServerEndpointsConfigurer endpoints) throws Exception {
	     endpoints
	       .authenticationManager(authenticationManager)
	       .userDetailsService(userDetailsService)
	       .tokenEnhancer(customTokenEnhancer())
	      // .pathMapping(defaultPath, customPath)
	       .tokenStore(tokenStore());
	     endpoints.allowedTokenEndpointRequestMethods(HttpMethod.GET, HttpMethod.POST);
	   }
///////////////////////////////////////////////////////////////

//  Or if there is no customPath Mapping or Tokenizer needed then remove above snippet and use below
//  Also make sure to remove CustomTokener file.
//    @Override
//    public void configure(final AuthorizationServerEndpointsConfigurer endpoints) {
//        endpoints.tokenStore(tokenStore())
//                .authenticationManager(authenticationManager)
//                .userDetailsService(userDetailsService);
//    }
   

    @Bean
    @Primary
    public DefaultTokenServices tokenServices() {
        final DefaultTokenServices defaultTokenServices = new DefaultTokenServices();
        defaultTokenServices.setTokenStore(tokenStore());
        defaultTokenServices.setSupportRefreshToken(true);
        return defaultTokenServices;
    }

    @Bean
    public TokenStore tokenStore() {
        return new JdbcTokenStore(dataSource);
    }   
}"

		else
			oauth2Config+="
	@Autowired
	@Qualifier(\"userDetailsService\")
	private UserDetailsService userDetailsService;

	@Autowired
	private AuthenticationManager authenticationManager;

		@Bean
    public PasswordEncoder passwordEncoder() {
        return PasswordEncoderFactories.createDelegatingPasswordEncoder();
    }

		@Bean
    public TokenStore tokenStore() {
        return new InMemoryTokenStore();
    }
	
	@Autowired
	private TokenStore tokenStore;

    @Override
    public void configure(ClientDetailsServiceConfigurer clients) throws Exception {
        clients.inMemory()
                .withClient(\"admin\")
                .secret(\"{noop}admin123\")
                .authorizedGrantTypes(\"refresh_token\", \"password\")
                .scopes(\"webclient\", \"mobileclient\")
                .accessTokenValiditySeconds(3600);
    }

////////////////////////////////////////////////////////////////
//	  If there is a customPath Mapping or Custom Tokenizer required use the below configure method
	@Bean
   public CustomTokenConverter customTokenEnhancer() {
       return new CustomTokenConverter();
   } 

	//Changes as per the CustomTokener as below
	public void configure(AuthorizationServerEndpointsConfigurer endpoints) throws Exception {
	     endpoints
	       .authenticationManager(authenticationManager)
	       .userDetailsService(userDetailsService)
	       .tokenEnhancer(customTokenEnhancer())
	      // .pathMapping(defaultPath, customPath)
	       .tokenStore(tokenStore);
	     endpoints.allowedTokenEndpointRequestMethods(HttpMethod.GET, HttpMethod.POST);
	   }
///////////////////////////////////////////////////////////////

//  Or if there is no customPath Mapping or Token Enhancer needed then remove above snippet and use below
//  Also make sure to remove CustomTokener file.
//    @Override
//    public void configure(final AuthorizationServerEndpointsConfigurer endpoints) {
//        endpoints.tokenStore(tokenStore)
//                .authenticationManager(authenticationManager)
//                .userDetailsService(userDetailsService);
//			endpoints.allowedTokenEndpointRequestMethods(HttpMethod.GET, HttpMethod.POST);
//    }
}"
		fi
		echo "$oauth2Config" >"$working_dir/security/OAuth2Config.java"

		echo "package "$package_name".security;
import java.util.HashMap;
import java.util.Map;

import org.springframework.security.oauth2.common.DefaultOAuth2AccessToken;
import org.springframework.security.oauth2.common.OAuth2AccessToken;
import org.springframework.security.oauth2.provider.OAuth2Authentication;
import org.springframework.security.oauth2.provider.token.TokenEnhancer;

import "$package_name".model.UserOAuth2;

public class CustomTokenConverter implements TokenEnhancer
{
   @Override
  public OAuth2AccessToken enhance(OAuth2AccessToken accessToken, OAuth2Authentication authentication)
 {
       UserOAuth2 loggedInUser = (UserOAuth2) authentication.getPrincipal();
       final Map<String, Object> additionalInfo = new HashMap<>();

       additionalInfo.put(\"name\", loggedInUser.getUsername());

       ((DefaultOAuth2AccessToken) accessToken).setAdditionalInformation(additionalInfo);

       return accessToken;
   }
}" >"$working_dir/security/CustomTokenConverter.java"

		echo "package "$package_name".security;

import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.oauth2.config.annotation.web.configuration.ResourceServerConfigurerAdapter;

@Configuration
public class ResourceServerWebSecurityConfigurer extends ResourceServerConfigurerAdapter 
{
    @Override
    public void configure(HttpSecurity http) throws Exception {
        http
            .authorizeRequests()
            .antMatchers(\"/user\").permitAll()            
            .anyRequest().authenticated()
            .and().csrf().disable();
    }
}" >"$working_dir/security/ResourceServerWebSecurityConfigurer.java"

		echo "package "$package_name".security;

import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import "$package_name".model.UserOAuth2;
import "$package_name".repository.UserOAuth2Repository;

@Service(\"userDetailsService\")
public class UserOAuth2Service implements UserDetailsService
{
	@Autowired
	private UserOAuth2Repository userOAuth2Repository;		
	
	@Override
	public UserDetails loadUserByUsername(String email) 
	{
		Optional<UserOAuth2> user= userOAuth2Repository.findByEmail(email);
		if(!user.isPresent())
		{
			throw new UsernameNotFoundException(null);
		}
		return user.get();	
	}
}" >"$working_dir/security/UserOAuth2Service.java"

		echo "package "$package_name".repository;

import java.util.Optional;

import org.springframework.data.repository.CrudRepository;

import com.dheeraj.cms.proj.model.UserOAuth2;

public interface UserOAuth2Repository extends CrudRepository<UserOAuth2, Long> 
{
	Optional<UserOAuth2> findByEmail(String email);
}" >"$working_dir/repository/UserOAuth2Repository.java"

		webSecurityConfigurer="package "$package_name".security;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.builders.AuthenticationManagerBuilder;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configuration.WebSecurityConfigurerAdapter;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.client.OAuth2ClientContext;
import org.springframework.security.oauth2.client.filter.OAuth2ClientContextFilter;
import org.springframework.security.oauth2.config.annotation.web.configuration.EnableOAuth2Client;
"

		if [[ $* == *oauth2-db* ]]; then
			webSecurityConfigurer+="
@Configuration
@EnableOAuth2Client
public class WebSecurityConfigurer extends WebSecurityConfigurerAdapter
{
	@Autowired
    OAuth2ClientContext oauth2ClientContext;

	
	@Override
    @Bean
    public AuthenticationManager authenticationManagerBean() throws Exception {
        return super.authenticationManagerBean();
    }		
	
	@Bean
    public FilterRegistrationBean<OAuth2ClientContextFilter> oauth2ClientFilterRegistration(OAuth2ClientContextFilter filter)
	{		
        FilterRegistrationBean<OAuth2ClientContextFilter> registration = new FilterRegistrationBean<OAuth2ClientContextFilter>();
        registration.setFilter(filter);
        registration.setOrder(-100);
        return registration;
    }
}"

			printf '\e[1;34m%-6s\e[m \e[1;35m%-6s\e[m \e[1;34m%-6s\e[m \e[1;35m%-6s\e[m \e[1;34m%-6s\e[m \e[1;35m%-6s\e[m' "OAuth2-db configuration has added mysql lines in" "import.sql" "with OAuth Client Credentials are user_name:" "admin" "and password:" "admin123
"

			for i in main test; do

				echo "
" >>src/$i/resources/import.sql

				sed -i '1i\
\
create table if not exists oauth_client_details(client_id VARCHAR(255) PRIMARY KEY,resource_ids VARCHAR(255),client_secret VARCHAR(255),scope VARCHAR(255),authorized_grant_types VARCHAR(255),web_server_redirect_uri VARCHAR(255),authorities VARCHAR(255),access_token_validity INTEGER,refresh_token_validity INTEGER,additional_information VARCHAR(4096),autoapprove VARCHAR(255));\
\
create table if not exists oauth_access_token (token_id VARCHAR(255),token BLOB,authentication_id VARCHAR(255) PRIMARY KEY,user_name VARCHAR(255),client_id VARCHAR(255),authentication BLOB,refresh_token VARCHAR(255));\
\
create table if not exists oauth_refresh_token (token_id VARCHAR(255),token BLOB,authentication BLOB);\
\
INSERT INTO oauth_client_details(client_id, client_secret, scope, authorized_grant_types,web_server_redirect_uri, authorities, access_token_validity,refresh_token_validity, additional_information, autoapprove)VALUES(\x27admin\x27, \x27{bcrypt}\$2a\$10\$bTqEsnkat8dqmJGYIKpEaeSYTHmfw/cKXrJe5dpRCBaAjzFloLDcO\x27, \x27admin,read,write\x27,\x27password,authorization_code,refresh_token\x27, NULL, NULL, 86400, 0, NULL, TRUE);\
' src/$i/resources/import.sql
			done

		else
			webSecurityConfigurer+="
@Configuration
@EnableWebSecurity
public class WebSecurityConfigurer extends WebSecurityConfigurerAdapter
{
	@Autowired
	@Qualifier(\"userDetailsService\")
	private UserDetailsService userDetailsService;

	@Autowired
	public PasswordEncoder passwordEncoder;
	
	@Override
    @Bean
    public AuthenticationManager authenticationManagerBean() throws Exception {
        return super.authenticationManagerBean();
    }	
	
	@Autowired
    public void globalUserDetails(AuthenticationManagerBuilder auth) throws Exception 
	{
        auth.userDetailsService(userDetailsService)
                .passwordEncoder(passwordEncoder);	
    }
}"

			echo "$webSecurityConfigurer" >"$working_dir/security/WebSecurityConfigurer.java"

			printf '\e[1;38m%-6s\e[m' "Generated Security Folder with all required files
Updated pom.xml files with required dependencies
Added Sample Controller
Generated User Model and Repo to support OAuth2 dependency."
		fi

	fi
fi
if [[ $1 == *"c"* ]]; then
	folder_values --c-folder "$*" .controller
	mkdir -p $working_dir${package_ext//.//}
	controller="package "$package_name${package_ext}";

import org.springframework.web.bind.annotation.RestController;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.validation.annotation.Validated;
"

	if [[ $* == *--need-sample* ]]; then
		controller+="import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
"
	fi

	if [[ $1 == *"s"* ]]; then
		folder_values --s-folder "$*" .service
		controller+="import org.springframework.beans.factory.annotation.Autowired;
import "$package_name${package_ext}.${fileName}"Service;
		"
	fi

	folder_values --c-folder "$*" .controller
	controller+="
@Transactional
@Validated
@RestController
public class "${fileName}"Controller 
{
"
	if [[ $1 == *"s"* ]]; then
		controller+="	@Autowired
	private "${fileName}"Service "$smallCase"Service;
	"
	fi
	if [[ $* == *--need-sample* ]]; then
		controller+="
	@GetMapping(\"/"$smallCase"/{id}\")
	public ResponseEntity<Void> getRequest(@PathVariable(\"id\") @NotNull @Min(1) long id)
	{
		//Accepts No Data from client but used to retrieve information
		//PathVariable is used to retrieve values present along request path
		//Also validates with value is not passed or is less than 1
		return ResponseEntity.status(HttpStatus.OK).build();
	}
	
	@PostMapping(\"/"$smallCase"\")
	public ResponseEntity<Void> postRequest(@RequestBody String jsonData)
	{
		//Accepts Data from client that is to be stored in Database
		//RequestBody is used to retrieve object from body tag of HTML Request
		return ResponseEntity.status(HttpStatus.OK).build();
	}
	
	@PutMapping(\"/"$smallCase"\")
	public ResponseEntity<Void> putRequest(@RequestHeader(\"id\") @NotNull @Min(1) long id)
	{
		//Accepts Data from client that is to be update the data stored in Database
		//RequestHeader is used to retrieve data from header part of HTML Request
		//Also validates with value is not passed or is less than 1
		return ResponseEntity.status(HttpStatus.OK).build();
	}
	
	@DeleteMapping(\"/"$smallCase"\")
	public ResponseEntity<Void> deleteRequest(@RequestParam(\"id\") @NotNull @Min(1) long id)
	{
		//Accepts Data from client that is to be deleted from Database
		//RequestParam is used to retrieve object from path/url where format is like 
			// localhost:8080/farmObjectiveAssessment?id=2
		//Also validates with value is not passed or is less than 1
		return ResponseEntity.status(HttpStatus.OK).build();
	}"
	fi
	controller+="
}"

	if [[ $* == *--overwrite* ]]; then
		echo "$controller" >"$working_dir/controller/${fileName}Controller.java"
	elif [ -f "$working_dir${package_ext//.//}/${fileName}Controller.java" ] && [ -s "$working_dir${package_ext//.//}/${fileName}Controller.java" ]; then
		echo -e "\033[1;31mIt seems the CONTROLLER file is already being created, or has data.
	So either safeguard it before re-executing
	or create another controller using c <newControllerName>tag
	or overwrite current one using only c <oldControllerName> --overwrite flag"
	else
		echo "$controller" >"$working_dir${package_ext//.//}/${fileName}Controller.java"
	fi
	#Create Test file for the same

	echo "package "$package_name".controller;

import org.junit.Test;

public class "${fileName}"ControllerTest
{
	@Test
	public void first"${fileName}"Test()
	{

	}
}" >"$working_test_dir/controller/${fileName}ControllerTest.java"
fi

if [[ $1 == *"m"* ]]; then
	folder_values --m-folder "$*" .model
	mkdir -p $working_dir${package_ext//.//}
	if [ -f "$working_dir${package_ext//.//}/${fileName}.java" ] && [ -s "$working_dir${package_ext//.//}/${fileName}.java" ]; then
		echo -e "\033[1;31mIt seems the MODEL file is already being created, or has data.
	So either safeguard it before re-executing
	or create another model using m <newModelName> tag"
	else
		model="package "$package_name${package_ext}";

import javax.persistence.*;
import com.fasterxml.jackson.annotation.JsonIgnore;

import java.util.*;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@Entity
@Table(name=\"$smallCaseWithUnderscore\")
public class ${fileName} 
{
	@Id
	@GeneratedValue(strategy=GenerationType.IDENTITY)
	@Column(name=\""$smallCaseWithUnderscore"_id\", nullable = false)
	private long "$smallCase"Id;
	
"
		folder_values --d-folder "$*" .dto
		if [ -f "$working_dir${package_ext//.//}/${fileName}DTO.java" ] && [ -s "$working_dir${package_ext//.//}/${fileName}DTO.java" ]; then
			echo -e "\033[1;31mIt seems the DTO file is already being created, or has data.
	So either safeguard it before re-executing
	or create another model using m <newModelName> tag"
		else
			dto="package "$package_name${package_ext}";

import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;
import javax.validation.constraints.Size;
import javax.validation.constraints.Min;
import javax.validation.constraints.Max;
import lombok.Getter;
import lombok.Setter;

import java.util.*;

@Getter
@Setter
public class ${fileName}DTO
{
"
		fi
		sqlInitialData="#INSERT INTO $smallCaseWithUnderscore("
		sqlRestData='VALUES('
		while true; do
			printf '\e[1;34m%-6s\e[m' "Just press Enter to skip out"
			printf "\n"
			read -e -p "propName in camelCase: " propName
			[[ -n "$propName" ]] || break
			propName=$(javaVariable $propName)
			prop_Name=$(dbVariable $propName)
			sqlInitialData+="${prop_Name},"
			options=("int" "String" "long" "boolean" "Date")
			validationType=("@NotNull @Min(0) @Max(1)" "@NotNull @NotBlank @Size(max=255)" "@NotNull" "@NotNull" "@NotNull")
			for ((i = 0; i < ${#options[@]}; i++)); do
				string="$(($i + 1))) ${options[$i]}"
				echo "$string"
			done

			while true; do
				read -e -p 'Enter dataType of the property: ' opt
				if [ "$opt" -ge 1 -a "$opt" -le 5 ]; then
					dT=${options[$opt - 1]}
					vT=${validationType[$opt - 1]}
					sqlRestData+=$(importSqlFormatter "<${propName}:${dT}>")
					break
				fi
			done

			options=("complusory and unique" "complusory" "optional")

			for ((i = 0; i < ${#options[@]}; i++)); do
				string="$(($i + 1))) ${options[$i]}"
				echo "$string"
			done

			while true; do
				read -e -p 'Enter mandatory status of the property: ' opt
				if [ "$opt" -ge 1 -a "$opt" -le 3 ]; then
					n=${options[$opt - 1]}
					if [[ $n == "complusory and unique" ]]; then
						mandatory="nullable=false, unique=true"
					elif [[ $n == "complusory" ]]; then
						mandatory="nullable=false"
					else
						mandatory="nullable=true"
						vT=""
					fi
					break
				fi
			done

			model+="	@Column(name=\"$prop_Name\", $mandatory)
	private $dT $propName;

"
			dto+="	$vT
	private $dT $propName;
	
"
		done

		options=("M2M" "M21" "12M" "121P" "121C")

		for ((i = 0; i < ${#options[@]}; i++)); do
			string="$(($i + 1))) ${options[$i]}"
			echo "$string"
		done

		while true; do

			printf '\e[1;34m%-6s\e[m' "Just press Enter to skip out from relationalMapping
"
			read -e -p 'Enter the relationship type from the above options to be added in this model: ' opt
			[[ -n "$opt" ]] || break
			if [ "$opt" -ge 4 -a "$opt" -le 1 ]; then
				break
			fi
			opt=${options[$opt - 1]}
			read -e -p 'Type the Model Name that you want to relate this model to: ' relatedModel
			relatedModel=$(echo "$relatedModel" | sed 's/^./\U&\E/')
			smallCaseOfRelatedModel=$(javaVariable $relatedModel)
			smallCaseOfRelatedModelWithUnderscore=$(dbVariable $smallCaseOfRelatedModel)

			case $opt in
			M2M)
				model+="	@ManyToMany(cascade = {CascadeType.PERSIST, CascadeType.MERGE}, fetch = FetchType.LAZY)
        @JoinTable(
            name = \"${smallCaseOfRelatedModelWithUnderscore}es\",
            joinColumns = {@JoinColumn(name = \""$smallCaseWithUnderscore"_id\")},
            inverseJoinColumns = {@JoinColumn(name = \""$smallCaseOfRelatedModelWithUnderscore"_id\")}
        )
        private Set<$relatedModel> $smallCaseOfRelatedModel = new HashSet<>();
"
				modelInPrint+="
	Add this in snippet in the $relatedModel Entity file
	
	@ManyToMany(cascade = {CascadeType.PERSIST, CascadeType.MERGE}, fetch = FetchType.LAZY)
    @JoinTable(
        name = \"${smallCaseOfRelatedModelWithUnderscore}es\",
        joinColumns = {@JoinColumn(name = \""$smallCaseOfRelatedModelWithUnderscore"_id\")},
        inverseJoinColumns = {@JoinColumn(name = \""$smallCaseWithUnderscore"_id\")}
    )
    private Set<${fileName}> $smallCase = new HashSet<>();
"
				;;
			M21)
				model+="	@ManyToOne
	@JoinColumn(name=\""$smallCaseOfRelatedModelWithUnderscore"_id\",referencedColumnName=\""$smallCaseOfRelatedModelWithUnderscore"_id\")
	private $relatedModel $smallCaseOfRelatedModel;
"
				sqlInitialData+="${smallCaseOfRelatedModelWithUnderscore}_id,"
				sqlRestData+="<${smallCaseOfRelatedModelWithUnderscore}_id:${relatedModel} Unique Column>,"

				modelInPrint+="
	Add this in snippet in the $relatedModel Entity file
	
	@JsonIgnore
	@OneToMany(targetEntity=${fileName}.class, mappedBy=\"$smallCaseOfRelatedModel\", fetch=FetchType.LAZY, cascade=CascadeType.REMOVE, orphanRemoval=false)
	private List<${fileName}> $smallCase;
"
				;;
			12M)
				model+="	@JsonIgnore
		@OneToMany(targetEntity=$relatedModel.class, mappedBy=\"$smallCase\", fetch=FetchType.LAZY, cascade=CascadeType.REMOVE, orphanRemoval=false)
		private List<$relatedModel> $smallCaseOfRelatedModel;
"

				modelInPrint+="
	Add this in snippet in the $relatedModel Entity file
	
	@ManyToOne
    @JoinColumn(name=\""$smallCaseWithUnderscore"_id\",referencedColumnName=\""$smallCaseWithUnderscore"_id\")
    private ${fileName} $smallCase;
	"
				;;
			121P)
				model+="	@JsonIgnore
	@OneToOne(targetEntity=$relatedModel.class, mappedBy=\"$smallCase\", fetch=FetchType.LAZY, cascade=CascadeType.REMOVE, orphanRemoval=false)
	private $relatedModel $smallCaseOfRelatedModel;
"
				modelInPrint+="
	Add this in snippet in the $relatedModel Entity file
	
	@OneToOne
	@JoinColumn(name=\""$smallCaseOfRelatedModelWithUnderscore"_id\",referencedColumnName=\""$smallCaseOfRelatedModelWithUnderscore"_id\",nullable=false)
	private ${fileName} $smallCase;
	"
				;;
			121C)
				model+="	@OneToOne
	@JoinColumn(name=\""$smallCaseOfRelatedModelWithUnderscore"_id\",referencedColumnName=\""$smallCaseOfRelatedModelWithUnderscore"_id\",nullable=false)
	private $relatedModel $smallCaseOfRelatedModel;
"
				sqlInitialData+="${smallCaseOfRelatedModelWithUnderscore}_id,"
				sqlRestData+="<${smallCaseOfRelatedModelWithUnderscore}_id:${relatedModel} Unique Column>,"

				modelInPrint+="
	Add this in snippet in the $relatedModel Entity file
	
	@JsonIgnore
	@OneToOne(targetEntity=${fileName}.class, mappedBy=\"$smallCaseOfRelatedModel\", fetch=FetchType.LAZY, cascade=CascadeType.REMOVE, orphanRemoval=false)
	private ${fileName} $smallCase;
	"
				;;
			esac
		done

		model+="}"
		dto+="}"

		echo "$dto" >"$working_dir${package_ext//.//}/${fileName}DTO.java"
		folder_values --m-folder "$*" .model
		echo "$model" >"$working_dir${package_ext//.//}/${fileName}.java"
		echo "$modelInPrint"

		if [[ $* == *--import-sql* ]]; then
			echo "" >>src/main/resources/import.sql
			for flag in $*; do
				if [[ $flag == -times* ]]; then
					flagVal=${flag:7}
					flagVal=${flagVal:-1}
					break
				fi
				flagVal=${flagVal:-1}
			done

			for ((n = 0; n < $flagVal; n++)); do
				finalSQLData+="${sqlInitialData::-1})${sqlRestData::-1});\n"
			done

			sed -i "\$a${finalSQLData}" src/main/resources/import.sql
		fi

		#Repository Code
		options=("CrudRepository" "JpaRepository")

		for ((i = 0; i < ${#options[@]}; i++)); do
			string="$(($i + 1))) ${options[$i]}"
			echo "$string"
		done

		while true; do
			read -e -p 'Repository type: ' opt
			if [ "$opt" -ge 1 -a "$opt" -le 2 ]; then
				repo=${options[$opt - 1]}
				break
			fi
		done

		folder_values --r-folder "$*" .repository
		repoCode="package "$package_name${package_ext}";
"

		case $repo in
		CrudRepository)
			repoCode+="import org.springframework.data.repository.CrudRepository;"
			;;
		JpaRepository)
			repoCode+="import org.springframework.data.jpa.repository.JpaRepository;"
			;;
		esac

		folder_values --m-folder "$*" .model
		repoCode+="
import "$package_name${package_ext}"."${fileName}";

public interface "${fileName}"Repository extends "$repo"<"${fileName}", Long> 
{

}"
		folder_values --r-folder "$*" .repository
		mkdir -p $working_dir${package_ext//.//}
		echo "$repoCode" >"$working_dir${package_ext//.//}/${fileName}Repository.java"
	fi
fi

if [[ $1 == *"s"* ]]; then

	folder_values --s-folder "$*" .service
	mkdir -p $working_dir${package_ext//.//}
	service="package "$package_name${package_ext}";

import org.springframework.stereotype.Service;
"

	if [[ $1 == *"m"* ]]; then
		folder_values --r-folder "$*" .repository
		service+="import org.springframework.beans.factory.annotation.Autowired;
import "$package_name${package_ext}"."${fileName}"Repository;
		"
	fi

	service+="
@Service
public class "${fileName}"Service 
{
"
	if [[ $1 == *"m"* ]]; then
		service+="	@Autowired
	private "${fileName}"Repository "$smallCase"Repository;"
	fi
	service+="
}"
	folder_values --s-folder "$*" .service
	if [[ $* == *--overwrite* ]]; then
		echo "$service" >"$working_dir${package_ext//.//}/${fileName}Service.java"
	elif [ -f "$working_dir${package_ext//.//}/${fileName}Service.java" ] && [ -s "$working_dir${package_ext//.//}/${fileName}Service.java" ]; then
		echo -e "\033[1;31mIt seems the SERVICE file is already being created, or has data.
	So either safeguard it before re-executing
	or create another model using s <newServiceName> tag
	or overwrite current one using only s <oldServiceName> --overwrite flag"
	else
		echo "$service" >"$working_dir${package_ext//.//}/${fileName}Service.java"
	fi
fi

if [[ $1 == *"a"* ]]; then
	folder_values --a-folder "$*" .aspect
	mkdir -p $working_dir${package_ext//.//}
	elemtype_options=("ANNOTATION_TYPE" "CONSTRUCTOR" "FIELD" "LOCAL_VARIABLE" "METHOD" "PACKAGE" "PARAMETER" "TYPE")

	for ((i = 0; i < ${#elemtype_options[@]}; i++)); do
		string="$(($i + 1))) ${elemtype_options[$i]}"
		echo "$string"
	done

	while true; do
		read -e -p 'ElementType of the aspect: ' opt
		if [ "$opt" -ge 1 -a "$opt" -le 8 ]; then
			elemType=${elemtype_options[$opt - 1]}
			break
		fi
	done

	rententionpolicy_options=("RUNTIME" "SOURCE" "CLASS")

	for ((i = 0; i < ${#rententionpolicy_options[@]}; i++)); do
		string="$(($i + 1))) ${rententionpolicy_options[$i]}"
		echo "$string"
	done

	while true; do
		read -e -p 'Retention Policy of the aspect: ' opt
		if [ "$opt" -ge 1 -a "$opt" -le 3 ]; then
			retenPolicy=${rententionpolicy_options[$opt - 1]}
			break
		fi
	done

	aspectInterface="package "$package_name${package_ext}";

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import org.springframework.core.annotation.AliasFor;

@Target(ElementType."$elemType")
@Retention(RetentionPolicy."$retenPolicy")
public @interface "${fileName}" {
"
	if [[ "$elemType" == "PARAMETER" ]]; then
		aspectInterface+="	@AliasFor(\"operationType\")
	String value() default \"\";
	
	@AliasFor(\"value\")
	String operationType() default \"\";
"
	fi
	aspectInterface+="}"
	echo "$aspectInterface" >"$working_dir${package_ext//.//}/${fileName}.java"

	aspectImpl="package "$package_name${package_ext}";

import java.lang.annotation.Annotation;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.SoftException;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.reflect.MethodSignature;
import org.springframework.stereotype.Component;

@Aspect
@Component
public class ${fileName}Aspect {"
	if [[ "$elemType" == "PARAMETER" ]]; then
		aspectImpl+="		
		@Around(\"execution(* *(.., @$package_name${package_ext}.${fileName} (*), ..))\")
		public Object "${fileName}"AspectImpl(ProceedingJoinPoint joinPoint) throws Throwable {
			Object[] args = joinPoint.getArgs();

			//get all annotations in the arguments
			MethodSignature signature = (MethodSignature) joinPoint.getSignature();
			String methodName = signature.getMethod().getName();
			Class<?>[] parameterTypes = signature.getMethod().getParameterTypes();
			Annotation[][] annotations;
			try {
				annotations = joinPoint.getTarget().getClass().
						getMethod(methodName, parameterTypes).getParameterAnnotations();
			} catch (Exception e) {
				throw new SoftException(e);
			}

			//Find annotated argument
			for (int i = 0; i < args.length; i++) {
				for (Annotation annotation : annotations[i]) {
					if (annotation.annotationType() == ${fileName}.class) {
						${fileName} fetchValue = (${fileName}) annotation;

						String val = fetchValue.value().isEmpty() ? 
							fetchValue.operationType() : fetchValue.value();
						// Perform operations over the data
						System.out.println(val);
						args[i] = val;
					}
				}
			}
			//execute original method with new args
			return joinPoint.proceed(args);
		}
"
	else
		aspectImpl+="
		@Around(\"@annotation($package_name${package_ext}.${fileName})\")
		public Object "${fileName}"AspectImpl(ProceedingJoinPoint joinPoint) throws Throwable {
			Object u = joinPoint.getArgs()[0];
			return joinPoint.proceed();
		}
"
	fi
	aspectImpl+="}"
	echo "$aspectImpl" >"$working_dir${package_ext//.//}/${fileName}Aspect.java"
fi
