package com.atenas.backend.dto.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Getter;

// @JsonInclude(NON_NULL): Jackson omite del JSON cualquier campo que sea null.
// Efecto: error responses no muestran "data: null" y success responses no muestran "errorCode: null".
@Getter
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ApiResponse<T> {

    private final boolean success;
    private final T data;
    private final String message;
    private final String errorCode;  // snake_case en JSON via config global (lo configuramos después)
    private final Object errors;     // para errores de validación (Bean Validation, Bloque 3+)

    // Constructor privado: nadie crea ApiResponse con `new`. Solo se usa a través de los métodos estáticos.
    private ApiResponse(boolean success, T data, String message, String errorCode, Object errors) {
        this.success = success;
        this.data = data;
        this.message = message;
        this.errorCode = errorCode;
        this.errors = errors;
    }

    // Respuesta exitosa con data
    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(true, data, null, null, null);
    }

    // Respuesta exitosa con data y mensaje descriptivo
    public static <T> ApiResponse<T> ok(T data, String message) {
        return new ApiResponse<>(true, data, message, null, null);
    }

    // Respuesta exitosa sin data (operaciones tipo "se registró correctamente")
    public static ApiResponse<Void> ok(String message) {
        return new ApiResponse<>(true, null, message, null, null);
    }

    // Error simple
    public static ApiResponse<Void> error(String message, String errorCode) {
        return new ApiResponse<>(false, null, message, errorCode, null);
    }

    // Error con lista de errores de validación (para el futuro @Valid)
    public static ApiResponse<Void> error(String message, String errorCode, Object errors) {
        return new ApiResponse<>(false, null, message, errorCode, errors);
    }
}