#!groovy
import java.lang.String

/***********************
 Jenkins pipeline stage to build the product
 ************************/
def exec(String branchOrCommit,
         String buildType='FAST',
         String buildScope='CI',
         String buildLabel='CEB-NewBuild',
         Boolean pushArtifactsToAzure=true,
         String skipComponents='',
         String clientDownloadLocation='',
         String buildBrandIndex='0',
         Boolean checkmarxScan=false,
         Boolean whitesourceScan=false) {

	final String buildSubJob = 'EndpointMidmarket/Shared/Midmarket-New-Build_Hermes'
    final String failedBuildArtifacts = 'Build.log, Failure.txt, **/Failure*.txt'
    final String buildArtifacts = 'Build.log, Failure.txt, build.properties, build_times.csv, git_commits.log, **/TEST*.xml, **/ui/coverage/cobertura-coverage.xml, **/junit-results.xml, **/TestResults/*.trx'
    final String buildLog = 'Build.log'

    def buildResult = build job: buildSubJob,
            propagate: false,
            parameters: [
                [$class: 'StringParameterValue', name: 'BUILD_TYPE', value: buildType],
                [$class: 'StringParameterValue', name: 'TFSBUILDTYPE', value: 'NightlyLite'],  //no longer used, but not yet removed
                [$class: 'StringParameterValue', name: 'BUILD_BRAND_INDEX', value: buildBrandIndex],
                [$class: 'StringParameterValue', name: 'BRANCH', value: branchOrCommit],
                [$class: 'StringParameterValue', name: 'BUILD_LEVEL', value: buildScope],
                [$class: 'LabelParameterValue', name: 'BUILD_LABEL', label: buildLabel],
                [$class: 'BooleanParameterValue', name: 'PUSH_ARTIFACTS_TO_AZURE', value: pushArtifactsToAzure],
                [$class: 'StringParameterValue', name: 'SKIP_COMPONENTS', value: skipComponents],
                [$class: 'StringParameterValue', name: 'CLIENT_DOWNLOAD_LOCATION', value: clientDownloadLocation],
                [$class: 'BooleanParameterValue', name: 'CHECKMARX_FULL_SCAN', value: checkmarxScan],
                [$class: 'BooleanParameterValue', name: 'WHITESOURCE_SCAN', value: whitesourceScan]
            ]

    if (buildResult.result != 'SUCCESS') {
        // Try to grab the logs if the build failed
        step([$class              : 'CopyArtifact',
              filter              : failedBuildArtifacts,
              fingerprintArtifacts: false,
              flatten             : true,
              optional            : true,
              selector            : specific(buildResult.id),
              projectName         : buildSubJob])
        archiveArtifacts artifacts: failedBuildArtifacts, fingerprint: true
        error('Build sub-job failed')
    }
    step([$class              : 'CopyArtifact',
          filter              : buildArtifacts,
          fingerprintArtifacts: true,
          flatten             : true,
          selector            : specific(buildResult.id),
          projectName         : buildSubJob])

    archiveArtifacts artifacts: buildArtifacts, fingerprint: true
    warnings parserConfigurations: [[parserName: 'MSBuild', pattern: buildLog]]

    // Parse Angular and C# Unit test results
    // Use XUnit to run it because the junt plugin complains if the files are too old
    step([$class: 'XUnitBuilder',
        tools: [[
            $class: 'JUnitType',
            pattern: 'TEST*.xml',
            healthScaleFactor: 1.0,
            allowEmptyResults: true,
            allowMissing: true,
            skipNoTestFiles: true
        ], 
        [
            $class: 'JUnitType',
            pattern: 'junit-results.xml',
            healthScaleFactor: 1.0,
            allowEmptyResults: true,
            allowMissing: true,
            skipNoTestFiles: true
        ],
		[
            $class: 'MSTestJunitHudsonTestType',
            pattern: '*.trx',
            healthScaleFactor: 1.0,
            allowEmptyResults: true,
            allowMissing: true,
            skipNoTestFiles: true
        ]]
    ])

    // Coverage Report for Angular
    step([
        $class: 'CoberturaPublisher',
        autoUpdateHealth: false,
        autoUpdateStability: false,
        coberturaReportFile: 'cobertura-coverage.xml',
        failUnhealthy: false,
        failUnstable: false,
        maxNumberOfBuilds: 0,
        onlyStable: false,
        sourceEncoding: 'ASCII',
        zoomCoverageChart: false,
        failNoReports: false
    ])

}

return this
