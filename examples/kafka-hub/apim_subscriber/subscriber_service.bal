// Copyright (c) 2025, WSO2 LLC. (http://www.wso2.org).
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

import ballerina/websub;
import ballerina/log;
import ballerina/os;

final string topicName = os:getEnv("TOPIC_NAME") == "" ? "priceUpdate" : os:getEnv("TOPIC_NAME");
final string hubUrl = os:getEnv("HUB_URL") == "" ? "https://lb:9090/hub" : os:getEnv("HUB_URL");
final boolean unsubOnShutdown = os:getEnv("UNSUB_ON_SHUTDOWN") == "true";
final string? callback = os:getEnv("CALLBACK_URL") == "" ? (): os:getEnv("CALLBACK_URL");
final string? secret = os:getEnv("SECRET") == "" ? (): os:getEnv("SECRET");
final string token = os:getEnv("AUTH_TOKEN") == "" ? "testtoken" : os:getEnv("AUTH_TOKEN");

listener websub:Listener securedSubscriber = getListener();

@websub:SubscriberServiceConfig {
    target: [hubUrl, topicName],
    httpConfig: {
        auth: {
            token
        },
        secureSocket: {
            enable: false
        }
    },
    unsubscribeOnShutdown: true
}
service /JuApTOXq19 on securedSubscriber {
    remote function onSubscriptionVerification(websub:SubscriptionVerification msg)
        returns websub:SubscriptionVerificationSuccess {
        log:printInfo(string `Successfully subscribed for notifications on topic [${topicName}]`);
        return websub:SUBSCRIPTION_VERIFICATION_SUCCESS;
    }

    remote function onEventNotification(websub:ContentDistributionMessage event) returns error? {
        json notification = check event.content.ensureType();
        log:printInfo("Received notification", content = notification);
    }    
}

isolated function getListener() returns websub:Listener|error {
    if os:getEnv("SVC_PORT") == "" {
        return new (10010, host = os:getEnv("HOSTNAME"));
    }
    return new (check int:fromString(os:getEnv("SVC_PORT")), host = os:getEnv("HOSTNAME"));
}

