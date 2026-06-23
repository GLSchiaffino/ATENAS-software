package com.atenas.backend.controller;

import com.atenas.backend.dto.response.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Map;

@RestController
@RequestMapping("/v1")
public class HealthController {

    @GetMapping("/health")
    public ApiResponse<Map<String, String>> health() {
        Map<String, String> data = Map.of(
                "status",    "UP",
                "service",   "ATENAS Backend",
                "timestamp", Instant.now().toString()
        );
        return ApiResponse.ok(data, "Sistema operativo");
    }
}