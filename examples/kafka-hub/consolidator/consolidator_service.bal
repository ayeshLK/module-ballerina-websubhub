// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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
import ballerina/websubhub;
import consolidatorService.config;
import consolidatorService.util;
import consolidatorService.connections as conn;
import consolidatorService.persistence as persist;
import consolidatorService.types;


isolated function startConsolidator() returns error? {
    do {
        while true {
            types:EventConsumerRecord[] records = check conn:websubEventConsumer->poll(config:POLLING_INTERVAL);
            foreach types:EventConsumerRecord currentRecord in records {
                error? result = processPersistedData(currentRecord.value);
                if result is error {
                    log:printError("Error occurred while processing received event ", 'error = result);
                }
            }
        }
    } on fail var e {
        log:printError("Error occurred while consuming records", 'error = e);
        _ = check conn:websubEventConsumer->close(config:GRACEFUL_CLOSE_PERIOD);
        return e;
    }
}

isolated function processPersistedData(json event) returns error? {
    string hubMode = check event.hubMode;
    match event.hubMode {
        "register" => {
            check processTopicRegistration(event);
        }
        "deregister" => {
            check processTopicDeregistration(event);
        }
        "subscribe" => {
            check processSubscription(event);
        }
        "unsubscribe" => {
            check processUnsubscription(event);
        }
        "restart" => {
            check processRestartEvent();
        }
        _ => {
            return error(string `Error occurred while deserializing subscriber events with invalid hubMode [${hubMode}]`);
        }
    }
}

isolated function processTopicRegistration(json payload) returns error? {
    websubhub:TopicRegistration registration = check payload.fromJsonWithType();
    readonly & types:EventHubPartition partitionMapping = check util:getNextPartition().cloneReadOnly();
    string topicName = util:sanitizeTopicName(registration.topic);
    lock {
        // add the topic if topic-registration event received
        if !registeredTopicsCache.hasKey(topicName) {
            registeredTopicsCache[topicName] = {
                topic: registration.topic,
                hubMode: registration.hubMode,
                partitionMapping: partitionMapping
            };
        }
        _ = check persist:persistTopicRegistrations(registeredTopicsCache);
    }
}

isolated function processTopicDeregistration(json payload) returns error? {
    websubhub:TopicDeregistration deregistration = check payload.fromJsonWithType();
    string topicName = util:sanitizeTopicName(deregistration.topic);
    types:TopicRegistration? topicRegistration = removeTopicRegistration(topicName);
    if topicRegistration is types:TopicRegistration {
        types:EventHubPartition partitionMapping = check topicRegistration?.partitionMapping.ensureType();
        util:updateVacantPartitionAssignment(partitionMapping.cloneReadOnly());
    }
    lock {
        _ = check persist:persistTopicRegistrations(registeredTopicsCache);
    }
}

isolated function removeTopicRegistration(string topicName) returns types:TopicRegistration? {
    lock {
        return registeredTopicsCache.removeIfHasKey(topicName).cloneReadOnly();
    }
}

isolated function processSubscription(json payload) returns error? {
    websubhub:VerifiedSubscription subscription = check payload.fromJsonWithType();
    types:EventHubPartition partitionMapping = check retrieveTopicPartitionMapping(subscription.hubTopic);
    types:EventHubConsumerGroup consumerGroupMapping = check util:getNextConsumerGroup(partitionMapping);
    subscription[NAMESPACE_ID] = consumerGroupMapping.namespaceId;
    subscription[EVENT_HUB_NAME] = consumerGroupMapping.eventHub;
    subscription[EVENT_HUB_PARTITION] = consumerGroupMapping.partition;
    subscription[CONSUMER_GROUP] = consumerGroupMapping.consumerGroup;
    string subscriberId = util:generatedSubscriberId(subscription.hubTopic, subscription.hubCallback);
    lock {
        // add the subscriber if subscription event received
        if !subscribersCache.hasKey(subscriberId) {
            subscribersCache[subscriberId] = subscription.cloneReadOnly();
        }
        _ = check persist:persistSubscriptions(subscribersCache);
    }
}

isolated function retrieveTopicPartitionMapping(string hubTopic) returns types:EventHubPartition|error {
    string topicName = util:sanitizeTopicName(hubTopic);
    lock {
        types:TopicRegistration topicRegistration = registeredTopicsCache.get(topicName);
        types:EventHubPartition partitionMapping = check topicRegistration?.partitionMapping.ensureType();
        return partitionMapping.cloneReadOnly();
    }
}

isolated function processUnsubscription(json payload) returns error? {
    websubhub:VerifiedUnsubscription unsubscription = check payload.fromJsonWithType();
    string subscriberId = util:generatedSubscriberId(unsubscription.hubTopic, unsubscription.hubCallback);
    websubhub:VerifiedSubscription? subscription = removeSubscription(subscriberId);
    if subscription is websubhub:VerifiedSubscription {
        readonly & types:EventHubConsumerGroup consumerGroupMapping = {
            namespaceId: check subscription[NAMESPACE_ID].ensureType(),
            eventHub: check subscription[EVENT_HUB_NAME].ensureType(),
            partition: check subscription[EVENT_HUB_PARTITION].ensureType(),
            consumerGroup: check subscription[CONSUMER_GROUP].ensureType()
        };
        util:updateVacantConsumerGroupAssignment(consumerGroupMapping.cloneReadOnly());
    }
    lock {
        _ = check persist:persistSubscriptions(subscribersCache);
    }
}

isolated function removeSubscription(string subscriberId) returns websubhub:VerifiedSubscription? {
    lock {
        return subscribersCache.removeIfHasKey(subscriberId).cloneReadOnly();
    }
}

isolated function processRestartEvent() returns error? {
    lock {
        _ = check persist:persistTopicRegistrations(registeredTopicsCache);
    }
    lock {
        _ = check persist:persistSubscriptions(subscribersCache);
    }
}
