#!/bin/bash 

working_dir=$(find src/main/java -name *Application.java | sed 's|/[^/]*$||' | head -n 1)
#working_test_dir=$(find src/test/java -name *ApplicationTests.java | sed 's|/[^/]*$||' | head -n 1)
working_test_dir="${working_dir//main/test}"
package_name=$(echo $working_dir | cut -c 15- | tr "/" .)

function javaVariable()
{
  local smallCase=$(echo "$1" | sed 's/^./\L&\E/')
  echo "$smallCase"
}

function dbVariable()
{
  local smallCaseWithUnderscore=$(echo "$1" | sed -e 's/\([^[:blank:]]\)\([[:upper:]]\)/\1_\2/g' | tr '[:upper:]' '[:lower:]')

  echo "$smallCaseWithUnderscore"
}

smallCase=$(javaVariable $2)   
smallCaseWithUnderscore=$(dbVariable $smallCase)   

mkdir -p $working_test_dir/controller

if [[ $1 == *--pluginCodeGen* ]]; then
	if [[ $* == *sonar* ]]; then
		nameLine=$(grep -n "<name>" pom.xml | cut -d ':' -f 1)

		projName=$(sed -e "${nameLine}q;d" pom.xml | sed -e 's/<[^>]*>//g' | sed "s/^[ \t]*//" )

		projNameInSmall=$(echo "$projName" | tr '[:upper:]' '[:lower:]')

		pluginLine=$(grep -n "</plugin>" pom.xml | cut -d ':' -f 1)
		sed -i "${pluginLine}i\
		</plugin>\
			<plugin>\
				<groupId>org.apache.maven.plugins</groupId>\
				<artifactId>maven-surefire-plugin</artifactId>\
			</plugin>\
			<plugin>\
	           <groupId>org.jacoco</groupId>\
	           <artifactId>jacoco-maven-plugin</artifactId>\
	           <version>0.8.0</version>\
	           <executions>\
	               <execution>\
	                   <id>default-prepare-agent</id>\
	                   <goals>\
	                       <goal>prepare-agent</goal>\
	                   </goals>\
	               </execution>\
	               <execution>\
	                   <id>default-report</id>\
	                   <phase>prepare-package</phase>\
	                   <goals>\
	                       <goal>report</goal>\
	                   </goals>\
	               </execution>\
	           </executions>\
       	</plugin>\
		</plugins>\
			<finalName>${projNameInSmall}</finalName>\
	</build>\
	<packaging>war</packaging>" pom.xml

	sed -i "$((pluginLine+1)),$((pluginLine+3))d" pom.xml

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

sonar.java.binaries=target/classes
sonar.java.test.binaries=./target/test-classes/${packageInBrackets}" > sonar-project.properties
	
	printf '\e[1;35m%-6s\e[m' "Perform Ctrl+A and Ctrl+I to format pom.xml file
"
	fi

	if [[ $* == *multiLang-support* ]]; then
		mkdir -p src/main/resources/languageTranslations
echo "{
	\"hello\": \"Hello\"
}" > src/main/resources/languageTranslations/en.json

echo "{
	\"hello\": \"Hallo\"
}" > src/main/resources/languageTranslations/de.json
		sed -i '26i\
			\
		<dependency>\
            <groupId>com.jayway.jsonpath</groupId>\
    		<artifactId>json-path</artifactId>\
       </dependency>' pom.xml

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

// Any model that has langCode has in it's model will have this line and this file will have
// it's equivalent @OneToMany mapping
//	@ManyToOne
//	@JoinColumn(name=\"language_translations_id\",referencedColumnName=\"language_translations_id\",nullable=false)
//	private LanguageTranslations languageTranslations;
}" > "$working_dir/model/LanguageTranslations.java"

echo "package "$package_name".repository;

import org.springframework.data.repository.CrudRepository;
import java.util.Optional;
import "$package_name.model.LanguageTranslations";

public interface LanguageTranslationsRepository extends CrudRepository<LanguageTranslations, Long> 
{
	Optional<LanguageTranslations> findByLanguageName(String languageName);
}" > "$working_dir/repository/LanguageTranslationsRepository.java"

		echo "package "$package_name".aspect;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface LanguageChecker {}
" > "$working_dir/aspect/LanguageChecker.java"

		echo "package "$package_name".aspect;

import java.lang.annotation.Annotation;
import java.lang.reflect.Field;
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
			Field f = String.class.getDeclaredField(\"value\");
			f.setAccessible(true);
			f.set(locale, new String(locale).concat(\";\").concat(languageTranslationService.getTranslationLanguageData(locale)).toCharArray());
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
}" > "$working_dir/aspect/LanguageCheckerAspect.java"
		
		echo "package "$package_name".controller;

import java.util.HashMap;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

import "$package_name".service.LanguageTranslationService;
		
@RestController
public class LanguageTranslationController 
{
	@Autowired
	private LanguageTranslationService languageTranslationService;
	
	@GetMapping(\"/langCode\")
	public ResponseEntity<Map<String, String>> getLangCodeAndJson(@RequestHeader(\"Accept-Language\")String locale)
	{
		String[] localeInfoData = languageTranslationService.getTranslationLanguageData(locale).split(\";\");
		
		Map<String, String> localeData = new HashMap<>();
		localeData.put(\"locale\", localeInfoData[0]);
		localeData.put(\"localeJson\", localeInfoData[1]);
		
		return ResponseEntity.status(HttpStatus.ACCEPTED).body(localeData);
	}
}" > "$working_dir/controller/LanguageTranslationController.java" 

echo "package "$package_name".service;

import java.io.File;
import java.nio.file.Files;

import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

@Service
public class LanguageTranslationService 
{
	String os = System.getProperty(\"os.name\").toLowerCase().indexOf(\"win\") >= 0 ? \"\\\\\": \"/\";
	
	public String getTranslationLanguageData(String locale)
	{
		try
		{
			File resource = new ClassPathResource(\"languageTranslations\"+os+locale+\".json\").getFile();
			return new String(Files.readAllBytes(resource.toPath()));
		}
		catch (Exception e) 
		{
			e.printStackTrace();
			return null;
		}		
	}
}" > "$working_dir/service/LanguageTranslationService.java" 
		printf '\e[1;34m%-6s\e[m \e[1;36m%-6s\e[m' "Add these lines in this file -> import.sql" "
INSERT INTO language_translations(language_name)VALUES('en');
INSERT INTO language_translations(language_name)VALUES('de');
"
	fi
	if [[ $* == *freemaker* ]]; then
	mkdir -p $working_dir/controller
		sed -i '26i\
			\
		<dependency>\
           <groupId>org.springframework.boot</groupId>\
           <artifactId>spring-boot-starter-freemarker</artifactId>\
       </dependency>\
       <dependency>\
  		  	<groupId>org.apache.poi</groupId>\
    	  	<artifactId>poi</artifactId>\
    	  	<version>3.10-FINAL</version>\
		</dependency>' pom.xml

       sed -i '3i\
spring.freemarker.template-loader-path: classpath:/static\
spring.freemarker.suffix: .ftl' src/main/resources/application.properties

echo "<#import "/spring.ftl" as spring />

<!DOCTYPE html>
<html lang=\"en\">
    <head>
        <meta charset=\"UTF-8\"> 
    </head>
    
    <body align=\"center\">
    
    	<@spring.bind \"user\"/>
    	<h2>Hello there to ${user}</h2>
    </body>
</html>" > src/main/resources/static/sample.ftl

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
}" > "$working_dir/controller/FreeMakerController.java"
	fi

	if [[ $* == *mysql* ]]; then
	
		sed -i '26i\
		\
		<dependency>\
			<groupId>com.h2database</groupId>\
			<artifactId>h2</artifactId>\
			<scope>test</scope>\
		</dependency>\
		<dependency>\
			<groupId>mysql</groupId>\
			<artifactId>mysql-connector-java</artifactId>\
			<scope>runtime</scope>\
		</dependency>\
		<dependency>\
			<groupId>org.projectlombok</groupId>\
			<artifactId>lombok</artifactId>\
			<optional>true</optional>\
		</dependency>' pom.xml

		echo "" > src/main/resources/application.properties
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
server.servlet.context-path=/*someContextPath*' src/main/resources/application.properties

touch src/test/resources/application.properties

echo "" > src/test/resources/application.properties

sed -i '1i\
spring.jpa.hibernate.ddl-auto=create\
spring.datasource.url=jdbc:h2:mem:db;DB_CLOSE_ON_EXIT=FALSE\
spring.datasource.username=sa\
spring.datasource.password=sa\
spring.jpa.database-platform=org.hibernate.dialect.H2Dialect\
spring.h2.console.enabled=true\
spring.datasource.driverClassName=org.h2.Driver' src/test/resources/application.properties
	fi

	if [[ $* == *oauth2* ]]; then
	mkdir -p $working_dir/{controller,service,model,repository,security}
		sed -i '26i\
		\
		<dependency>\
			<groupId>org.springframework.boot</groupId>\
			<artifactId>spring-boot-starter-security</artifactId>\
		</dependency>\
		<dependency>\
			<groupId>org.springframework.security</groupId>\
			<artifactId>spring-security-test</artifactId>\
			<scope>test</scope>\
		</dependency>\
			<dependency>\
  		    <groupId>org.springframework.security.oauth</groupId>\
  		 	<artifactId>spring-security-oauth2</artifactId>\
   		 	<version>2.3.3.RELEASE</version>\
		</dependency>' pom.xml

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
	
	@PostMapping(\"/logout\")
    public ResponseEntity<Void> logout(HttpServletRequest request)
    {
       String authorization = request.getHeader(\"Authorization\");
       if (authorization != null && authorization.contains(\"Bearer\"))
       {
           String tokenId = authorization.substring(\"Bearer\".length()+1);
           tokenServices.revokeToken(tokenId);
       }      
       return ResponseEntity.ok(null);      
    }
}" > "$working_dir/controller/OAuth2Controller.java"
			
echo "package "$package_name".repository;

import java.util.Optional;

import org.springframework.data.repository.CrudRepository;

import com.dheeraj.cms.proj.model.User;

public interface UserRepository extends CrudRepository<User, Long> 
{
	Optional<User> findByEmail(String email);
}" > "$working_dir/repository/UserRepository.java"
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
@Table(name=\"user\")
public class User implements UserDetails
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
}" > "$working_dir/model/User.java"

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
}" > "$working_dir/security/CorsFilter.java"

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
echo "$oauth2Config" > "$working_dir/security/OAuth2Config.java"

echo "package "$package_name".security;
import java.util.HashMap;
import java.util.Map;

import org.springframework.security.oauth2.common.DefaultOAuth2AccessToken;
import org.springframework.security.oauth2.common.OAuth2AccessToken;
import org.springframework.security.oauth2.provider.OAuth2Authentication;
import org.springframework.security.oauth2.provider.token.TokenEnhancer;

import "$package_name".model.User;

public class CustomTokenConverter implements TokenEnhancer
{
   @Override
  public OAuth2AccessToken enhance(OAuth2AccessToken accessToken, OAuth2Authentication authentication)
 {
       User user = (User) authentication.getPrincipal();
       final Map<String, Object> additionalInfo = new HashMap<>();

       additionalInfo.put(\"name\", user.getName());

       ((DefaultOAuth2AccessToken) accessToken).setAdditionalInformation(additionalInfo);

       return accessToken;
   }
}" > "$working_dir/security/CustomTokenConverter.java"

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
}" > "$working_dir/security/ResourceServerWebSecurityConfigurer.java"

echo "package "$package_name".security;

import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import "$package_name".model.User;
import "$package_name".repository.UserRepository;

@Service(\"userDetailsService\")
public class UserService implements UserDetailsService
{
	@Autowired
	private UserRepository userRepository;		
	
	@Override
	public UserDetails loadUserByUsername(String email) 
	{
		Optional<User> user=userRepository.findByEmail(email);
		if(!user.isPresent())
		{
			throw new UsernameNotFoundException(null);
		}
		return user.get();	
	}
}" > "$working_dir/security/UserService.java"
	
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
import org.springframework.security.oauth2.config.annotation.web.configuration.EnableOAuth2Client;"

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

printf '\e[1;34m%-6s\e[m \e[1;35m%-6s\e[m \e[1;34m%-6s\e[m \e[1;35m%-6s\e[m \e[1;34m%-6s\e[m \e[1;35m%-6s\e[m \e[1;32m%-6s\e[m' "Make sure to write this mysql lines in" "import.sql" "where OAuth Client Credentials are user_name:" "admin" "and password:" "admin123" "

create table if not exists oauth_client_details(client_id VARCHAR(255) PRIMARY KEY,resource_ids VARCHAR(255),client_secret VARCHAR(255),scope VARCHAR(255),authorized_grant_types VARCHAR(255),web_server_redirect_uri VARCHAR(255),authorities VARCHAR(255),access_token_validity INTEGER,refresh_token_validity INTEGER,additional_information VARCHAR(4096),autoapprove VARCHAR(255));

create table if not exists oauth_access_token (token_id VARCHAR(255),token BLOB,authentication_id VARCHAR(255) PRIMARY KEY,user_name VARCHAR(255),client_id VARCHAR(255),authentication BLOB,refresh_token VARCHAR(255));

create table if not exists oauth_refresh_token (token_id VARCHAR(255),token BLOB,authentication BLOB);

INSERT INTO oauth_client_details(client_id, client_secret, scope, authorized_grant_types,web_server_redirect_uri, authorities, access_token_validity,refresh_token_validity, additional_information, autoapprove)VALUES('admin', '{bcrypt}\$2a\$10\$bTqEsnkat8dqmJGYIKpEaeSYTHmfw/cKXrJe5dpRCBaAjzFloLDcO', 'admin,read,write','password,authorization_code,refresh_token', NULL, NULL, 86400, 0, NULL, TRUE);
"

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

echo "$webSecurityConfigurer" > "$working_dir/security/WebSecurityConfigurer.java"
fi

	fi
fi
if [[ $1 == *"c"* ]]; then
mkdir -p $working_dir/controller
  controller="package "$package_name".controller;

import org.springframework.web.bind.annotation.RestController;
"

	if [[ $* == *--need-sample* ]]; then
		controller+="import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
"
	fi

	if [[ $1 == *"s"* ]]; then
		controller+="import org.springframework.beans.factory.annotation.Autowired;
import "$package_name".service."$2"Service;
		"
	fi

controller+="
@RestController
public class "$2"Controller 
{
"			
	if [[ $1 == *"s"* ]]; then
	controller+="	@Autowired
	private "$2"Service "$smallCase"Service;
	"
	fi
	if [[ $* == *--need-sample* ]]; then
		controller+="
	@GetMapping(\"/"$smallCase"/{id}\")
	public ResponseEntity<Void> getRequest(@PathVariable(\"id\") long id)
	{
		//Accepts No Data from client but used to retrieve information
		//PathVariable is used to retrieve values present along request path
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
	public ResponseEntity<Void> putRequest(@RequestHeader(\"id\") long id)
	{
		//Accepts Data from client that is to be update the data stored in Database
		//RequestHeader is used to retrieve data from header part of HTML Request
		return ResponseEntity.status(HttpStatus.OK).build();
	}
	
	@DeleteMapping(\"/"$smallCase"\")
	public ResponseEntity<Void> deleteRequest(@RequestParam(\"id\") long id)
	{
		//Accepts Data from client that is to be deleted from Database
		//RequestParam is used to retrieve object from path/url where format is like 
			// localhost:8080/farmObjectiveAssessment?id=2
		return ResponseEntity.status(HttpStatus.OK).build();
	}"
	fi
controller+="
}"

if [[ $* == *--overwrite* ]]; then
	echo "$controller" > "$working_dir/controller/$2Controller.java"
elif [ -f "$working_dir/controller/$2Controller.java" ] && [ -s "$working_dir/controller/$2Controller.java" ]; then
	echo -e "\033[1;31mIt seems the CONTROLLER file is already being created, or has data.
	So either safeguard it before re-executing
	or create another controller using c <newControllerName>tag
	or overwrite current one using only c <oldControllerName> --overwrite flag";
else
	echo "$controller" > "$working_dir/controller/$2Controller.java"
fi	
#Create Test file for the same

echo "package "$package_name".controller;

import org.junit.Test;

public class "$2"ControllerTest
{
	@Test
	public void first"$2"Test()
	{

	}
}" > "$working_test_dir/controller/$2ControllerTest.java"
fi


if [[ $1 == *"m"* ]]; then
mkdir -p $working_dir/model
if [ -f "$working_dir/model/$2.java" ] && [ -s "$working_dir/model/$2.java" ]; then
	echo -e "\033[1;31mIt seems the MODEL file is already being created, or has data.
	So either safeguard it before re-executing
	or create another model using m <newModelName> tag";
else
  model="package "$package_name".model;

import javax.persistence.*;
import com.fasterxml.jackson.annotation.JsonIgnore;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@Entity
@Table(name=\"$smallCaseWithUnderscore\")
public class $2 
{
	@Id
	@GeneratedValue(strategy=GenerationType.IDENTITY)
	@Column(name=\""$smallCaseWithUnderscore"_id\", nullable = false)
	private long "$smallCase"Id;
	
"

while true; do
  printf '\e[1;34m%-6s\e[m' "Just press Enter to skip out"
  printf "\n"
   read -e -p "propName : " propName
     [[ -n "$propName" ]] || break
    propName=$(javaVariable $propName)
    prop_Name=$(dbVariable $propName) 
options=("int" "String" "long" "boolean")

for ((i=0;i<${#options[@]};i++)); do 
  string="$(($i+1))) ${options[$i]}"
  echo "$string"
done

while true; do
  read -e -p 'Enter dataType of the property: ' opt
if [ "$opt" -ge 1 -a "$opt" -le 4 ]; then   
    dT=${options[$opt-1]}	
    break;
   fi
done

options=("true" "false")

for ((i=0;i<${#options[@]};i++)); do 
  string="$(($i+1))) ${options[$i]}"
  echo "$string"
done

while true; do
  read -e -p 'Enter nullable status of the property: ' opt
if [ "$opt" -ge 1 -a "$opt" -le 2 ]; then   
    n=${options[$opt-1]}	
    break;
   fi
done

for ((i=0;i<${#options[@]};i++)); do 
  string="$(($i+1))) ${options[$i]}"
  echo "$string"
done

while true; do
  read -e -p 'Enter unique status of the property: ' opt
if [ "$opt" -ge 1 -a "$opt" -le 2 ]; then   
    t=${options[$opt-1]}
    break;
   fi
done

    model+="	@Column(name=\"$prop_Name\", nullable=$n, unique=$t)
	private $dT $propName;

"
done

options=("M21" "12M" "121P" "121C")

for ((i=0;i<${#options[@]};i++)); do 
  string="$(($i+1))) ${options[$i]}"
  echo "$string"
done

while true; do

	read -e -p 'Enter the relationship to be used in this model: ' opt
	[[ -n "$opt" ]] || break
	if [ "$opt" -ge 4 -a "$opt" -le 1 ]; then   
		break;
   	fi
	opt=${options[$opt-1]}	
	read -e -p 'Type the Model Name that you want to relate this model to: ' relatedModel

		smallCaseOfRelatedModel=$(javaVariable $relatedModel)
		smallCaseOfRelatedModelWithUnderscore=$(dbVariable $smallCaseOfRelatedModel)

case $opt in
	M21)
		model+="	@ManyToOne
    @JoinColumn(name=\""$smallCaseOfRelatedModelWithUnderscore"_id\",referencedColumnName=\""$smallCaseOfRelatedModelWithUnderscore"_id\")
    private $relatedModel $smallCaseOfRelatedModel;
"

	modelInPrint+="
	Add this in snippet in the $relatedModel Entity file
	
	@JsonIgnore
	@OneToMany(targetEntity=$2.class, mappedBy=\"$smallCaseOfRelatedModel\", fetch=FetchType.LAZY, cascade=CascadeType.REMOVE, orphanRemoval=false)
	private List<$2> $smallCase;
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
    private $2 $smallCase;
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
	@JoinColumn(name=\""$smallCase"_id\",referencedColumnName=\""$smallCase"_id\",nullable=false)
	private $2 $smallCase;
	"
	;;
	121C)
	model+="	@OneToOne
	@JoinColumn(name=\""$smallCaseOfRelatedModelWithUnderscore"_id\",referencedColumnName=\""$smallCaseOfRelatedModelWithUnderscore"_id\",nullable=false)
	private $relatedModel $smallCaseOfRelatedModel;
"
	modelInPrint+="
	Add this in snippet in the $relatedModel Entity file
	
	@JsonIgnore
	@OneToOne(targetEntity=$2.class, mappedBy=\"$smallCaseOfRelatedModel\", fetch=FetchType.LAZY, cascade=CascadeType.REMOVE, orphanRemoval=false)
	private $2 $smallCase;
	"
	;;
esac
done

model+="}" 

echo "$model" > "$working_dir/model/$2.java"
echo "$modelInPrint"

#Repository Code
options=("CrudRepository" "JpaRepository")

for ((i=0;i<${#options[@]};i++)); do 
  string="$(($i+1))) ${options[$i]}"
  echo "$string"
done

while true; do
  read -e -p 'Repository type: ' opt
if [ "$opt" -ge 1 -a "$opt" -le 2 ]; then   
    repo=${options[$opt-1]}	
    break;
   fi
done

repoCode="package "$package_name".repository;
"

case $repo in 
CrudRepository)
	repoCode+="import org.springframework.data.repository.CrudRepository;"
	;;
JpaRepository)
	repoCode+="import org.springframework.data.jpa.repository.JpaRepository;"
	;;
esac

repoCode+="
import "$package_name.model.$2";

public interface "$2"Repository extends "$repo"<"$2", Long> 
{

}" 
mkdir -p $working_dir/repository
echo "$repoCode" > "$working_dir/repository/$2Repository.java"
fi
fi

if [[ $1 == *"s"* ]]; then
mkdir -p $working_dir/service
  service="package "$package_name".service;

import org.springframework.stereotype.Service;
"

	if [[ $1 == *"m"* ]]; then
		service+="import org.springframework.beans.factory.annotation.Autowired;
import "$package_name".repository."$2"Repository;
		"
	fi

service+="
@Service
public class "$2"Service 
{
"			
	if [[ $1 == *"m"* ]]; then
	service+="	@Autowired
	private "$2"Repository "$smallCase"Repository;"
	fi
service+="
}"
if [[ $* == *--overwrite* ]]; then
	echo "$service" > "$working_dir/service/$2Service.java"
elif [ -f "$working_dir/service/$2Service.java" ] && [ -s "$working_dir/service/$2Service.java" ]; then
	echo -e "\033[1;31mIt seems the SERVICE file is already being created, or has data.
	So either safeguard it before re-executing
	or create another model using s <newServiceName> tag
	or overwrite current one using only s <oldServiceName> --overwrite flag";
else
	echo "$service" > "$working_dir/service/$2Service.java"
fi
fi

if [[ $1 == *"a"* ]]; then
mkdir -p $working_dir/aspect
elemtype_options=("ANNOTATION_TYPE" "CONSTRUCTOR" "FIELD" "LOCAL_VARIABLE" "METHOD" "PACKAGE" "PARAMETER" "TYPE")

for ((i=0;i<${#elemtype_options[@]};i++)); do 
  string="$(($i+1))) ${elemtype_options[$i]}"
  echo "$string"
done

while true; do
  read -e -p 'ElementType of the aspect: ' opt
if [ "$opt" -ge 1 -a "$opt" -le 8 ]; then   
    elemType=${elemtype_options[$opt-1]}	
    break;
   fi
done

rententionpolicy_options=("RUNTIME" "SOURCE" "CLASS")

for ((i=0;i<${#rententionpolicy_options[@]};i++)); do 
  string="$(($i+1))) ${rententionpolicy_options[$i]}"
  echo "$string"
done

while true; do
  read -e -p 'Retention Policy of the aspect: ' opt
if [ "$opt" -ge 1 -a "$opt" -le 3 ]; then   
    retenPolicy=${rententionpolicy_options[$opt-1]}	
    break;
   fi
done

echo "package "$package_name".aspect;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Target(ElementType."$elemType")
@Retention(RetentionPolicy."$retenPolicy")
public @interface "$2" {

}" > "$working_dir/aspect/$2.java"

echo "package "$package_name".aspect;

import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;

public class $2Aspect 
{
	@Around(\"@annotation($package_name.$2)\")
	public Object "$2"AspectImpl(ProceedingJoinPoint joinPoint) throws Throwable {
		Object u = joinPoint.getArgs()[0];
		return joinPoint.proceed();
	}
}" > "$working_dir/aspect/$2Aspect.java"

fi
