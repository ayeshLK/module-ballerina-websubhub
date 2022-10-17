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
import ballerinax/kafka;

public type EventHubPartition record {|
    string namespaceId;
    string eventHub;
    int partition;
|};

public type EventHubConsumerGroup record {|
    *EventHubPartition;
    string consumerGroup;
|};

public type VacantMapping record {|
    string mode;
    EventHubPartition|EventHubConsumerGroup mapping;
|};

public type VacantMappingsConsumerRecord record {|
    *kafka:AnydataConsumerRecord;
    VacantMapping value;
|};

public type TopicRegistration record {
    *websubhub:TopicRegistration;
};

public type HubRestartEvent record {|
    string hubMode = "restart";
|};

public type ConsolidatedTopicsConsumerRecord record {|
    *kafka:AnydataConsumerRecord;
    TopicRegistration[] value;
|};

public type ConsolidatedSubscribersConsumerRecord record {|
    *kafka:AnydataConsumerRecord;
    websubhub:VerifiedSubscription[] value;
|};

public type EventConsumerRecord record {|
    *kafka:AnydataConsumerRecord;
    json value;
|};
