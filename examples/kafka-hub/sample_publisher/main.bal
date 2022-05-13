// Copyright (c) 2022, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
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

import ballerina/websubhub;
import ballerina/lang.runtime;
import ballerina/log;

configurable string HUB_URL = "http://websubhub.privatelink.websubhub.io:80/hub";

final websubhub:PublisherClient publisherClient = check new(HUB_URL);

final string TOPIC = "ASGARDEO_EVENTS";
final readonly & json PAYLOAD = {
    "type": "Message",
    "content": "Sample Text Message"
};

public function main() returns error? {
    websubhub:TopicRegistrationSuccess registrationResponse = check publisherClient->registerTopic(TOPIC);
    log:printInfo("Received topic-registration response", payload = registrationResponse);
    _ = @strand {thread: "any"} start publishContent();
}

function publishContent() returns error? {
    while (true) {
        runtime:sleep(5);
        websubhub:Acknowledgement response = check publisherClient->publishUpdate(TOPIC, PAYLOAD);
        log:printInfo("Received content publish response", payload = response);
    }
}
