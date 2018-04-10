@Library('jenkins-libs')
import ru.etecar.Libs
import ru.etecar.HelmClient
import ru.etecar.HelmRelease
import ru.etecar.HelmRepository

node ('gce-standard-4-ssd') {
    cleanWs()
    checkout scm
    stage ('Build image'){
        def dataVersion = "20180405"
        def buildFromImageTag = "3.1.0-russia-20180405-3"
        def imageRepo = 'eu.gcr.io/indigo-terra-120510'
        def appName = 'nominatim-docker'
        def imageTag = "3.1.0-russia-${dataVersion}-${env.BUILD_NUMBER}"
        docker.withRegistry(imageRepo, 'google-docker-repo') {
            sh "cd 3.0 && docker build --build-arg BUILD_IMAGE=${imageRepo}/${appName}:${buildFromImageTag} -t ${imageRepo}:${imageTag} --file Dockerfile-updatebuild . && docker push ${imageRepo}/${appName}:${buildFromImageTag}"
         }    
    }
}
node ('docker-server'){
    Libs utils = new Libs(steps)
    HelmClient helm = new HelmClient(steps)
    HelmRepository repo = new HelmRepository(steps,"helmrepo","https://nexus:8443/repository/helmrepo/")
    try {
        cleanWs()
        appName = 'nominatim-docker'
        nominatimVer = '3.0'
        imageTag = "3.1.0-russia-20180405"
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
                helm.waitForDeploy(nominatimRelease, 400)
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