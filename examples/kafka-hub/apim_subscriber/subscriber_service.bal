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

configurable string topicName = "priceUpdate";
configurable string hubUrl = "https://localhost:9090";
configurable boolean logHeaders = false;
configurable string token = "testtoken";

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
service /JuApTOXq19 on new websub:Listener(10010) {
    remote function onSubscriptionVerification(websub:SubscriptionVerification msg)
        returns websub:SubscriptionVerificationSuccess {
        log:printInfo(string `Successfully subscribed for notifications on topic [${topicName}]`);
        return websub:SUBSCRIPTION_VERIFICATION_SUCCESS;
    }

    remote function onEventNotification(websub:ContentDistributionMessage event) returns error? {
        json notification = check event.content.ensureType();
        log:printInfo("Received notification", content = notification);
        if logHeaders {
            map<string|string[]>? receivedHeaders = event.headers;
            if receivedHeaders is () {
                return;
            }
            log:printInfo("Received headers: ", headers = receivedHeaders);
        }
    }    
}
