/*
 * Copyright 2000-2020 JetBrains s.r.o.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.jetbrains;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.ServiceLoader;

/**
 * Marker interface, can be used with Java SPI to enumerate JBR services
 * All JBR services must implement this interface
 */
public interface JBRService {


    /**
     * Loads JBR service for given interface
     */
    @SuppressWarnings("unchecked")
    static <T extends JBRService> T load(Class<T> serviceInterface) {
        JBRServiceManager.ServiceHolder<T> serviceHolder =
                (JBRServiceManager.ServiceHolder<T>) JBRServiceManager.services.get(serviceInterface);
        return serviceHolder == null ? null : serviceHolder.get();
    }

    static boolean areAnyServicesAvailable() {
        return JBRServiceManager.services.size() > 0;
    }


}

class JBRServiceManager {

    static class ServiceHolder<T extends JBRService> {
        private ServiceLoader.Provider<T> provider;
        private T service;
        private ServiceHolder(ServiceLoader.Provider<T> provider) {
            this.provider = provider;
        }
        synchronized T get() {
            if(service != null) return service;
            service = provider.get();
            provider = null;
            return service;
        }
    }

    static final Map<Class<? extends JBRService>, ServiceHolder<?>> services;
    static {
        Map<Class<? extends JBRService>, ServiceHolder<?>> map = new HashMap<>();
        ServiceLoader.load(JBRService.class).stream()
                .forEach(p -> populateServiceMap(map, new ServiceHolder<>(p), p.type()));
        services = Collections.unmodifiableMap(map);
    }

    @SuppressWarnings("unchecked")
    private static boolean populateServiceMap(Map<Class<? extends JBRService>, ServiceHolder<?>> map,
                                              ServiceHolder<?> serviceHolder, Class<?> clazz) {
        if(clazz == null) return false;
        if(clazz.equals(JBRService.class)) return true;
        boolean isSubtypeOfJBRService = false;
        for(Class<?> ifc : clazz.getInterfaces()) {
            if(populateServiceMap(map, serviceHolder, ifc)) {
                isSubtypeOfJBRService = true;
                break;
            }
        }
        if(!isSubtypeOfJBRService) {
            isSubtypeOfJBRService = populateServiceMap(map, serviceHolder, clazz.getSuperclass());
        }
        if(isSubtypeOfJBRService) {
            map.put((Class<? extends JBRService>) clazz, serviceHolder);
        }
        return isSubtypeOfJBRService;
    }

}