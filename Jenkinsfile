@Library('jenkins-libs')
import ru.etecar.Libs
import ru.etecar.HelmClient
import ru.etecar.HelmRelease
import ru.etecar.HelmRepository
import java.time.ZonedDateTime
import static java.time.format.DateTimeFormatter.RFC_1123_DATE_TIME
import static java.time.format.DateTimeFormatter.BASIC_ISO_DATE

def imageTag = ""
def pbfRepository = "http://download.geofabrik.de/russia-latest.osm.pbf"
def imageRepo = 'eu.gcr.io/indigo-terra-120510'
def appName = 'nominatim-docker'
def lastImageTime
ZonedDateTime pbfDate

@NonCPS
String getLastPbfTimestamp(String url) {
    def baseUrl = new URL(url);
    HttpURLConnection connection = (HttpURLConnection) baseUrl.openConnection();
    connection.addRequestProperty("Accept", "application/json");
    connection.with {
        doOutput = false
        requestMethod = 'GET'
    }
    return connection.getHeaderField("Last-Modified");
}

node ('gce-standard-8-ssd') {
    def buildThreads = "16"
    cleanWs()
    checkout scm
    def dockerfile = ""
    def parameter = params.buildType
    def fromImage = "ubuntu:xenial"
    stage ('Build image'){
        if (parameter == "UpdateBuild"){
            try {
                copyArtifacts filter: 'pbf-timestamp', fingerprintArtifacts: true, projectName: "${env.JOB_NAME}", selector: lastSuccessful()
                lastImageTime = sh returnStdout: true, script: 'cat pbf-timestamp'
            }
            catch (e){
                throw new Exception("This is first time build, select fullbuild parameter.");
            }
            pbfDate = ZonedDateTime.parse(lastImageTime, RFC_1123_DATE_TIME);
            dockerfile = "Dockerfile-updatebuild";
            buildNum = env.BUILD_NUMBER.toInteger() - 1;
            prevImageTag = "3.1.0-russia-${pbfDate.format(BASIC_ISO_DATE)}-${buildNum}";
            fromImage = "${imageRepo}/${appName}:${prevImageTag}";
        }
        else if (parameter == "FullBuild"){
            try {
                copyArtifacts filter: 'pbf-timestamp', fingerprintArtifacts: true, projectName: "${env.JOB_NAME}", selector: lastSuccessful()
                lastImageTime = sh returnStdout: true, script: 'cat pbf-timestamp'
            }
            catch (e){
                echo "Assuming that it's first time build"
                lastImageTime = "Mon, 5 Jan 1970 00:00:00 GMT"
            }
        
            def lastModefied = getLastPbfTimestamp(pbfRepository);
            echo "lastModefied: ${lastModefied}"
            pbfDate = ZonedDateTime.parse(lastModefied, RFC_1123_DATE_TIME);
            previousPbfDate = ZonedDateTime.parse(lastImageTime, RFC_1123_DATE_TIME);
            echo "previousPbfDate: ${previousPbfDate.format(RFC_1123_DATE_TIME)}"
        
            if (!pbfDate.isAfter(previousPbfDate)) {
                throw new Exception("no changes in geofabric repo. No build needed");
            }
            dockerfile = "Dockerfile-fullbuild";
        }
        else {
            throw new Exception("No build parameter specified");
        }
        
        imageTag = "3.1.0-russia-${pbfDate.format(BASIC_ISO_DATE)}-${env.BUILD_NUMBER}";
        sh "echo -n \"${pbfDate.format(RFC_1123_DATE_TIME)}\"> pbf-timestamp"
        archiveArtifacts 'pbf-timestamp'
        withCredentials([file(credentialsId: 'google-docker-repo', variable: 'CREDENTIALS')]) {
            sh "mkdir -p ~/.docker && cat \"${CREDENTIALS}\" > ~/.docker/config.json"
        }          
        sh "cd 3.0 && docker build -t ${imageRepo}/${appName}:${imageTag} --build-arg BUILD_IMAGE=${fromImage} --build-arg THREADS=${buildThreads} --file ${dockerfile} . && docker push ${imageRepo}/${appName}:${imageTag}"
    }
}
node ('docker-server'){
    Libs utils = new Libs(steps)
    HelmClient helm = new HelmClient(steps)
    HelmRepository repo = new HelmRepository(steps,"helmrepo","https://nexus:8443/repository/helmrepo/")
    try {
        cleanWs()
        nominatimVer = '3.0'
        kubeProdContext = "google-system"

        checkout scm
        helm.init('helm')
        helm.repoAdd(repo)

        stage('Build helm'){
            withCredentials([usernameColonPassword(credentialsId: "nexus", variable: 'CREDENTIALS')]) {
                repo.push(helm.buildPacket("${nominatimVer}/helm/${appName}/Chart.yaml"), CREDENTIALS, "helm-repo")
            }
        }

        stage ('Production') {
            def stage = "production"
            def apiProdHostname = "maps.etecar.ru"
            HelmRelease nominatimRelease = new HelmRelease(steps, "${appName}", "helmrepo/${appName}")

            try {
                helm.tillerNamespace = "kube-system"
                helm.kubeContext = kubeProdContext

                nominatimRelease.namespace = "${stage}"
                nominatimRelease.values = [
                        "ingress.enabled":"true",
                        "ingress.hosts[0]":"${ apiProdHostname}",
                        "image.tag" : "${imageTag}"
                ]
                helm.upgrade( nominatimRelease )
                helm.waitForDeploy(nominatimRelease, 3600)
            } catch (e) {
                helm.rollback(nominatimRelease)
                throw e
            }
        }
    } catch (e) {
        utils.sendMail("${env.JOB_NAME} (${env.BUILD_NUMBER}) has finished with FAILED", "See ${env.BUILD_URL}")
        throw e
    }
}