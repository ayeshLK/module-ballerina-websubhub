// Copyright (c) 2021 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/log;
import ballerina/http;
import ballerina/test;
import ballerina/regex;

listener Listener hubListenerToAdditionalErrorDetails = new(9093);

Service hubServiceToTestAdditionalErrorDetails = service object {

    isolated remote function onRegisterTopic(TopicRegistration message)
                                returns TopicRegistrationError {
        return error TopicRegistrationError("Topic registration failed!",
                        statusCode = http:STATUS_OK,
                        body = { "hub.additional.details": "Feature is not supported in the hub"});
    }

    isolated remote function onDeregisterTopic(TopicDeregistration message)
                        returns TopicDeregistrationError {
        return error TopicDeregistrationError("Topic deregistration failed!", statusCode = http:STATUS_OK);
    }

    isolated remote function onUpdateMessage(UpdateMessage msg)
               returns UpdateMessageError {
        return error UpdateMessageError("Error in accessing content",
                    statusCode = http:STATUS_BAD_REQUEST,
                    body = { "hub.additiona.details": "Content update failed!"});
    }
    
    isolated remote function onSubscription(Subscription msg)
                returns SubscriptionAccepted|BadSubscriptionError|InternalSubscriptionError {
        SubscriptionAccepted successResult = {
                statusCode: http:STATUS_ACCEPTED,
                body: <map<string>>{
                       isSuccess: "true"
                    }
            };
        if (msg.hubTopic == "test") {
            return successResult;
        } else {
            return error BadSubscriptionError("Bad subscription", statusCode = http:STATUS_BAD_REQUEST);
        }
    }

    isolated remote function onSubscriptionValidation(Subscription msg)
                returns SubscriptionDeniedError? {
        if (msg.hubTopic != "test") {
            return error SubscriptionDeniedError("Denied subscription for topic 'test1'", statusCode = http:STATUS_BAD_REQUEST);
        }
    }

    isolated remote function onSubscriptionIntentVerified(VerifiedSubscription msg) {
        log:printDebug("Subscription Intent verified invoked!");
    }

    isolated remote function onUnsubscription(Unsubscription msg)
               returns UnsubscriptionAccepted|BadUnsubscriptionError|InternalUnsubscriptionError {
        if (msg.hubTopic == "test") {
            UnsubscriptionAccepted successResult = {
                statusCode: http:STATUS_ACCEPTED,
                body: <map<string>>{
                       isSuccess: "true"
                    }
            };
            return successResult;
        } else {
            return error BadUnsubscriptionError("Denied unsubscription for topic '" + msg.hubTopic + "'", statusCode = http:STATUS_BAD_REQUEST);
        }
    }

    isolated remote function onUnsubscriptionValidation(Unsubscription msg)
                returns UnsubscriptionDeniedError? {
        if (msg.hubTopic != "test") {
            return error UnsubscriptionDeniedError("Denied subscription for topic 'test1'", statusCode = http:STATUS_BAD_REQUEST);
        }
        return ();
    }

    isolated remote function onUnsubscriptionIntentVerified(VerifiedUnsubscription msg){
        log:printDebug("Unsubscription Intent verified invoked!");
    }
};

@test:BeforeGroups { value:["additional-error-details"] }
function beforeAdditionalErrorDetailsTest() returns error? {
    check hubListenerToAdditionalErrorDetails.attach(hubServiceToTestAdditionalErrorDetails, "websubhub");
}

@test:AfterGroups { value:["additional-error-details"] }
function afterAdditionalErrorDetailsTest() returns error? {
    check hubListenerToAdditionalErrorDetails.gracefulStop();
}

http:Client errorDetailsTestClientEp = check new("http://localhost:9093/websubhub");

@test:Config {
    groups: ["additional-error-details"]
}
function testRegistrationFailureErrorDetails() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=register&hub.topic=test1", "application/x-www-form-urlencoded");

    http:Response response = check errorDetailsTestClientEp->post("/", request);
    test:assertEquals(response.statusCode, 200);
    string payload = check response.getTextPayload();
    map<string> responseBody = decodeResponseBody(payload);
    test:assertEquals(responseBody["hub.mode"], "denied");
    test:assertEquals(responseBody["hub.reason"], "Topic registration failed!");
    test:assertEquals(responseBody["hub.additional.details"], "Feature is not supported in the hub");
}

@test:Config {
    groups: ["additional-error-details"]
}
function testDeregistrationFailureErrorDetails() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=deregister&hub.topic=test1", "application/x-www-form-urlencoded");

    http:Response response = check errorDetailsTestClientEp->post("/", request);
    test:assertEquals(response.statusCode, 200);
    string payload = check response.getTextPayload();
    map<string> responseBody = decodeResponseBody(payload);
    test:assertEquals(responseBody["hub.mode"], "denied");
    test:assertEquals(responseBody["hub.reason"], "Topic deregistration failed!");
}

@test:Config {
    groups: ["additional-error-details"]
}
function testUpdateMessageErrorDetails() returns error? {
    http:Request request = new;
    request.setTextPayload("hub.mode=publish&hub.topic=test", "application/x-www-form-urlencoded");

    http:Response response = check errorDetailsTestClientEp->post("/", request);
    test:assertEquals(response.statusCode, 200);
    string payload = check response.getTextPayload();
    map<string> responseBody = decodeResponseBody(payload);
    test:assertEquals(responseBody["hub.mode"], "denied");
    test:assertEquals(responseBody["hub.reason"], "Error in accessing content"); 
}

isolated function decodeResponseBody(string payload) returns map<string> {
    map<string> body = {};
    if (payload.length() > 0) {
        string[] splittedPayload = regex:split(payload, "&");
        foreach string bodyPart in splittedPayload {
            string[] responseComponent =  regex:split(bodyPart, "=");
            if (responseComponent.length() == 2) {
                body[responseComponent[0]] = responseComponent[1];
            }
        }
        return body;
    }
    return body;
} 