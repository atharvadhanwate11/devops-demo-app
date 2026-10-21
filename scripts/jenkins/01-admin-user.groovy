// Creates the local demo admin user (admin/admin) and locks down Jenkins.
// Runs automatically at Jenkins startup from $JENKINS_HOME/init.groovy.d/.
import jenkins.model.Jenkins
import jenkins.security.HudsonPrivateSecurityRealm
import hudson.security.FullControlOnceLoggedInAuthorizationStrategy

def jenkins = Jenkins.get()

def realm = new HudsonPrivateSecurityRealm(false, false, null)
def user = realm.createAccount("admin", "admin")
user.setFullName("DevOps Demo Admin")
jenkins.setSecurityRealm(realm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
jenkins.setAuthorizationStrategy(strategy)

jenkins.save()
println ">>> DevOps demo: admin/admin user created, anonymous access disabled"
