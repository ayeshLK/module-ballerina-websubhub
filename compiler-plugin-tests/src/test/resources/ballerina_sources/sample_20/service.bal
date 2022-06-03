// Copyright (c) 2022 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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
import ballerina/http;
import ballerina/io;

listener websubhub:Listener functionWithArgumentsListener = new(9090);

service /websubhub on functionWithArgumentsListener {
    isolated remote function onRegisterTopic(readonly & websubhub:TopicRegistration message, readonly & http:Headers headers)
                                returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError {
        if (message.topic == "test") {
            return websubhub:TOPIC_REGISTRATION_SUCCESS;
        } else {
            return websubhub:TOPIC_REGISTRATION_ERROR;
        }
    }

    isolated remote function onDeregisterTopic(readonly & websubhub:TopicDeregistration message, readonly & http:Headers headers)
                        returns websubhub:TopicDeregistrationSuccess|websubhub:TopicDeregistrationError {
        if (message.topic == "test") {
            return websubhub:TOPIC_DEREGISTRATION_SUCCESS;
        } else {
            return websubhub:TOPIC_DEREGISTRATION_ERROR;
        }
    }

    isolated remote function onUpdateMessage(readonly & websubhub:UpdateMessage msg, readonly & http:Headers headers)
               returns websubhub:Acknowledgement|websubhub:UpdateMessageError {
        if (msg.hubTopic == "test") {
            return websubhub:ACKNOWLEDGEMENT;
        } else if (!(msg.content is ())) {
            return websubhub:ACKNOWLEDGEMENT;
        } else {
            return websubhub:UPDATE_MESSAGE_ERROR;
        }
    }
    
    isolated remote function onSubscription(readonly & websubhub:Subscription msg, readonly & http:Headers headers)
                returns websubhub:SubscriptionAccepted|websubhub:SubscriptionPermanentRedirect|websubhub:SubscriptionTemporaryRedirect
                |websubhub:BadSubscriptionError|websubhub:InternalSubscriptionError {
        if (msg.hubTopic == "test") {
            return websubhub:SUBSCRIPTION_ACCEPTED;
        } else if (msg.hubTopic == "test1") {
            return websubhub:SUBSCRIPTION_ACCEPTED;
        } else {
            return websubhub:BAD_SUBSCRIPTION_ERROR;
        }
    }

    isolated remote function onSubscriptionValidation(readonly & websubhub:Subscription msg)
                returns websubhub:SubscriptionDeniedError? {
        if (msg.hubTopic == "test1") {
            return websubhub:SUBSCRIPTION_DENIED_ERROR;
        }
        return ();
    }

    isolated remote function onSubscriptionIntentVerified(readonly & websubhub:VerifiedSubscription msg) {
        io:println("Subscription Intent verified invoked!");
    }

    isolated remote function onUnsubscription(readonly & websubhub:Unsubscription msg, readonly & http:Headers headers)
               returns websubhub:UnsubscriptionAccepted|websubhub:BadUnsubscriptionError|websubhub:InternalUnsubscriptionError {
        if (msg.hubTopic == "test" || msg.hubTopic == "test1" ) {
            return websubhub:UNSUBSCRIPTION_ACCEPTED;
        } else {
            return websubhub:BAD_UNSUBSCRIPTION_ERROR;
        }
    }

    isolated remote function onUnsubscriptionValidation(readonly & websubhub:Unsubscription msg)
                returns websubhub:UnsubscriptionDeniedError? {
        if (msg.hubTopic == "test1") {
            return websubhub:UNSUBSCRIPTION_DENIED_ERROR;
        }
        return ();
    }

    isolated remote function onUnsubscriptionIntentVerified(readonly & websubhub:VerifiedUnsubscription msg){
        io:println("Unsubscription Intent verified invoked!");
    }
}
