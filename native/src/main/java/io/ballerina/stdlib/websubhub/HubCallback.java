/*
 * Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
 *
 * WSO2 Inc. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.stdlib.websubhub;

import io.ballerina.runtime.api.Future;
import io.ballerina.runtime.api.Module;
import io.ballerina.runtime.api.async.Callback;
import io.ballerina.runtime.api.creators.ErrorCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BString;

import java.util.Map;

import static io.ballerina.runtime.api.utils.StringUtils.fromString;
import static io.ballerina.stdlib.websubhub.Constants.COMMON_RESPONSE;
import static io.ballerina.stdlib.websubhub.Constants.PANIC_FROM_THE_SERVICE_ERROR;
import static io.ballerina.stdlib.websubhub.Constants.SERVICE_EXECUTION_ERROR;
import static io.ballerina.stdlib.websubhub.Constants.STATUS_CODE;

/**
 * {@code HubCallback} used to handle the websubhub remote method invocation results.
 */
public class HubCallback implements Callback {
    private final Future future;
    private final Module module;

    public HubCallback(Future future, Module module) {
        this.future = future;
        this.module = module;
    }

    @Override
    public void notifySuccess(Object result) {
        if (result instanceof BError) {
            BError error = (BError) result;
            if (!isModuleDefinedError(error)) {
                error.printStackTrace();
            }
        }

        future.complete(result);
    }

    @Override
    public void notifyFailure(BError bError) {
        bError.printStackTrace();
        BString errorMessage = fromString("service method invocation failed: " + bError.getErrorMessage());
        BMap<BString, Object> errorDetails = ValueCreator.createRecordValue(module, COMMON_RESPONSE,
                    Map.of(STATUS_CODE, PANIC_FROM_THE_SERVICE_ERROR));
        BError invocationError = ErrorCreator.createError(module, SERVICE_EXECUTION_ERROR,
                errorMessage, bError, errorDetails);
        future.complete(invocationError);
    }

    private boolean isModuleDefinedError(BError error) {
        Type errorType = error.getType();
        Module packageDetails = errorType.getPackage();
        String orgName = packageDetails.getOrg();
        String packageName = packageDetails.getName();
        return Constants.PACKAGE_ORG.equals(orgName) && Constants.PACKAGE_NAME.equals(packageName);
    }
}
