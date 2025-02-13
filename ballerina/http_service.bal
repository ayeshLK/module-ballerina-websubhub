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

import ballerina/http;
import ballerina/log;
import ballerina/mime;

isolated service class HttpService {
    *http:Service;

    private final HttpToWebsubhubAdaptor adaptor;
    private final string hub;
    private final int defaultHubLeaseSeconds;
    private final SubscriptionHandler subscriptionHandler;

    isolated function init(HttpToWebsubhubAdaptor adaptor, string hubUrl, int leaseSeconds,
            *ClientConfiguration clientConfig) {
        self.adaptor = adaptor;
        self.hub = hubUrl;
        self.defaultHubLeaseSeconds = leaseSeconds;
        self.subscriptionHandler = new (adaptor, leaseSeconds, clientConfig);
    }

    isolated resource function post .(http:Caller caller, http:Request request, http:Headers headers) returns Error? {
        http:Response response = new;
        map<string>|error params = self.retrieveParams(request, headers);
        if params is error {
            response.statusCode = http:STATUS_BAD_REQUEST;
            response.setTextPayload(params.message());
            return respondWithResult(caller, response);
        }

        string? mode = params[HUB_MODE];
        match mode {
            MODE_REGISTER => {
                http:Response|error result = processTopicRegistration(headers, params, self.adaptor);
                return respondWithResult(caller, result);
            }
            MODE_DEREGISTER => {
                http:Response|error result = processTopicDeregistration(headers, params, self.adaptor);
                return respondWithResult(caller, result);
            }
            MODE_SUBSCRIBE => {
                return self.handleSubscription(caller, headers, params);
            }
            MODE_UNSUBSCRIBE => {
                return self.handleUnsubscription(caller, headers, params);
            }
            MODE_PUBLISH => {
                http:Response|error result = processContentPublish(request, headers, params, self.adaptor);
                if result is error {
                    response.statusCode = http:STATUS_BAD_REQUEST;
                    response.setTextPayload(result.message());
                    return respondWithResult(caller, response);
                }
                return respondWithResult(caller, result);
            }
            _ => {
                response.statusCode = http:STATUS_BAD_REQUEST;
                string errorMessage = "The request does not include valid `hub.mode` form param.";
                response.setTextPayload(errorMessage);
                return respondWithResult(caller, response);
            }
        }
    }

    isolated function retrieveParams(http:Request request, http:Headers headers) returns map<string>|error {
        map<string> params = {};
        string contentTypeValue = request.getContentType();
        http:HeaderValue[] values = check http:parseHeader(contentTypeValue);
        string contentType = values[0].value;
        map<string[]> queryParams = request.getQueryParams();
        match contentType {
            mime:APPLICATION_FORM_URLENCODED => {
                string|http:HeaderNotFoundError publisherHeader = headers.getHeader(BALLERINA_PUBLISH_HEADER);
                if publisherHeader is string {
                    if publisherHeader == "publish" {
                        params[HUB_MODE] = check retrieveQueryParameter(queryParams, HUB_MODE);
                        params[HUB_TOPIC] = check retrieveQueryParameter(queryParams, HUB_TOPIC);
                    } else if publisherHeader == "event" {
                        params = check request.getFormParams();
                    } else {
                        return error("Invalid value for header " + BALLERINA_PUBLISH_HEADER);
                    }
                } else {
                    params = check request.getFormParams();
                }
            }
            mime:APPLICATION_JSON|mime:APPLICATION_XML|mime:APPLICATION_OCTET_STREAM|mime:TEXT_PLAIN => {
                params[HUB_MODE] = check retrieveQueryParameter(queryParams, HUB_MODE);
                params[HUB_TOPIC] = check retrieveQueryParameter(queryParams, HUB_TOPIC);
            }
            _ => {
                string errorMessage = "Endpoint only supports content type of application/x-www-form-urlencoded, " +
                                        "application/json, application/xml, application/octet-stream and text/plain";
                return error(errorMessage);
            }
        }
        return params;
    }

    isolated function handleSubscription(http:Caller caller, http:Headers headers, map<string> params) returns Error? {
        Subscription|error subscription = createSubscriptionMessage(self.hub, self.defaultHubLeaseSeconds, params);
        if subscription is Subscription {
            http:Response|Redirect result = self.subscriptionHandler.processSubscription(subscription, headers);
            if result is Redirect {
                error? redirectError = caller->redirect(new http:Response(), result.code, result.redirectUrls);
                if redirectError is error {
                    log:printError("Error occurred while redirecting the subscription", 'error = redirectError);
                }
                return;
            }

            int currentStatusCode = result.statusCode;
            if currentStatusCode == http:STATUS_ACCEPTED {
                check respondWithResult(caller, result);

                error? verificationResult = self.subscriptionHandler.processSubscriptionVerification(subscription, headers);
                if verificationResult is error {
                    log:printError("Error occurred while processing subscription", 'error = verificationResult);
                }
                return;
            }
            return respondWithResult(caller, result);
        }

        http:Response response = new;
        response.statusCode = http:STATUS_BAD_REQUEST;
        response.setTextPayload(subscription.message());
        return respondWithResult(caller, response);
    }

    isolated function handleUnsubscription(http:Caller caller, http:Headers headers, map<string> params) returns Error? {
        Unsubscription|error unsubscription = createUnsubscriptionMessage(params);
        if unsubscription is Unsubscription {
            http:Response result = self.subscriptionHandler.processUnsubscription(unsubscription, headers);
            int currentStatusCode = result.statusCode;
            if currentStatusCode == http:STATUS_ACCEPTED {
                check respondWithResult(caller, result);
                error? verificationResult = self.subscriptionHandler.processUnSubscriptionVerification(
                    unsubscription, headers);
                if verificationResult is error {
                    log:printError("Error occurred while processing unsubscription", 'error = verificationResult);
                }
                return;
            }
            return respondWithResult(caller, result);
        }

        http:Response response = new;
        response.statusCode = http:STATUS_BAD_REQUEST;
        response.setTextPayload(unsubscription.message());
        return respondWithResult(caller, response);
    }
}

isolated function respondWithResult(http:Caller caller, http:Response|error result) returns Error? {
    http:ListenerError? respondError = ();
    if result is error {
        http:Response response = new;
        response.statusCode = http:STATUS_BAD_REQUEST;
        response.setTextPayload(result.message());
        respondError = caller->respond(response);
    } else {
        respondError = caller->respond(result);
    }

    if respondError is http:ListenerError {
        return error Error("Error occurred while responding to the request ", respondError,
            statusCode = http:STATUS_INTERNAL_SERVER_ERROR);
    }
}
