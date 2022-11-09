// Copyright (c) 2022, WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/file;
import ballerina/io;
import ballerina/lang.runtime;
import ballerina/log;
import ballerina/websubhub;

configurable string HUB = ?;
configurable string TOPIC = ?;
configurable string RESULTS_FILE_PATH = ?;

final string SECRET = "test123$";
final readonly & json[] messages = [ADD_NEW_USER_MESSAGE, LOGIN_SUCCESS_MESSAGE];
final string[] & readonly documentationCsvHeaders = ["Label", "# Test Scenarios", "Success %", "Status"];

enum STATUS {
    SUCCESSFUL,
    FAILED,
    PARTIAL
}

const int TOTAL_SCENARIOS = 3;

public function main() returns error? {
    _ = check initializeTests();
    int failedScenarios = 0;
    
    websubhub:PublisherClient publisherClientEp = check new(HUB);
    websubhub:TopicRegistrationSuccess|error registrationResponse = registerTopic(publisherClientEp);
    if registrationResponse is error {
        log:printError("Error occurred while registering the topic", 'error = registrationResponse);
        failedScenarios += 1;
    }

    runtime:sleep(90);
    error? publishResponse = publishContent(publisherClientEp);
    if publishResponse is error {
        log:printError("Error occurred while publishing content", 'error = publishResponse);
        failedScenarios += 1;
    }

    websubhub:TopicDeregistrationSuccess|error deregistrationResponse = deregisterTopic(publisherClientEp);
    if deregistrationResponse is error {
        log:printError("Error occurred while de-registering the topic", 'error = deregistrationResponse);
        failedScenarios += 1;
    }
    
    STATUS testStatus = failedScenarios == 0 ? SUCCESSFUL : TOTAL_SCENARIOS == failedScenarios ? FAILED : PARTIAL;
    float successRate = (<float>(TOTAL_SCENARIOS - failedScenarios)/<float>TOTAL_SCENARIOS) * 100.0;
    any[] results = ["Azure WebSubHub", TOTAL_SCENARIOS, successRate, testStatus];
    return writeResultsToCsv(RESULTS_FILE_PATH, results);
}

function initializeTests() returns error? {
    boolean fileExists = check file:test(RESULTS_FILE_PATH, file:EXISTS);
    if !fileExists {
        check io:fileWriteCsv(RESULTS_FILE_PATH, [documentationCsvHeaders]);
    }
}

isolated function registerTopic(websubhub:PublisherClient publisherClientEp) returns websubhub:TopicRegistrationSuccess|error {
    return publisherClientEp->registerTopic(TOPIC);
}

isolated function publishContent(websubhub:PublisherClient publisherClientEp) returns error? {
    foreach json message in messages {
        _ = check publisherClientEp->publishUpdate(TOPIC, message);
    }
}

isolated function deregisterTopic(websubhub:PublisherClient publisherClientEp) returns websubhub:TopicDeregistrationSuccess|error {
    return publisherClientEp->deregisterTopic(TOPIC);
}

function writeResultsToCsv(string outputPath, any[] results) returns error? {
    string[][] summaryData = check io:fileReadCsv(outputPath);
    string[] finalResults = [];
    foreach var result in results {
        finalResults.push(result.toString());
    }
    summaryData.push(finalResults);
    check io:fileWriteCsv(outputPath, summaryData);
}