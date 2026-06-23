
---

# FASE 4 — Implementación Backend: Spring Boot

---

## 4.1 — ¿Qué hace Spring Boot exactamente?

**En una línea:** Spring Boot es un framework que gestiona la creación y conexión de los objetos de tu aplicación, y auto-configura la infraestructura (servidor web, conexión a BD, etc.).

**Lo que Spring Boot hace por vos automáticamente:**
- Levanta un servidor web embebido (Tomcat) — no instalás nada externo
- Detecta que tenés JPA en el classpath y configura Hibernate
- Crea la connection pool a PostgreSQL
- Escanea tus clases anotadas y crea los objetos
- Maneja la serialización/deserialización JSON (objeto Java ↔ JSON)

**Lo que vos hacés:**
- Escribís las clases con las anotaciones correctas
- Declarás qué dependencias necesita cada clase
- Ponés la lógica de negocio donde corresponde

---

## 4.2 — Inversión de Control (IoC) e Inyección de Dependencias

**El problema sin Spring:**
```java
// Sin framework: vos controlás la creación de objetos
VentaRepository repo = new VentaRepository();
VentaService service = new VentaService(repo);
VentaController controller = new VentaController(service);
// → vos sabés el orden, vos manejás las dependencias, vos gestionás el ciclo de vida
```

**Con Spring — Inversión de Control:**
```java
// Con Spring: vos declarás qué necesitás, Spring lo provee
@RestController
public class VentaController {

    private final VentaService ventaService;

    // Constructor Injection: Spring detecta este constructor e inyecta VentaService
    public VentaController(VentaService ventaService) {
        this.ventaService = ventaService;
    }
}
```

Spring escanea todas las clases anotadas con `@Component`, `@Service`, `@Repository`, `@Controller` y las registra en su **contenedor IoC**. Cuando detecta que `VentaController` necesita un `VentaService`, busca en el contenedor y lo inyecta automáticamente.

**¿Por qué "inversión"?** Porque el control de la creación de objetos se invierte: antes lo hacía tu código, ahora lo hace el framework.

**Beneficio práctico para ATENAS:** Al testear `VentaService`, podés inyectarle un `VentaRepository` falso (mock) sin cambiar ninguna línea de producción. La dependencia está declarada, no hardcodeada.

---

## 4.3 — Arquitectura en cuatro capas

```
[Tu app: navegador / celular]
          ↓  HTTP POST /v1/ventas
   @RestController → VentaController
          ↓  llama al service
      @Service → VentaService
          ↓  llama al repository
    @Repository → VentaRepository
          ↓  SQL vía Hibernate
     PostgreSQL 15
```

**Controller (`@RestController`):**
- Recibe el request HTTP
- Lee el body, los path params, los query params
- Valida que los campos obligatorios estén presentes (`@Valid`)
- Llama al servicio y devuelve la respuesta HTTP
- **No contiene lógica de negocio.** Si encontrás un `if` que decide algo del dominio en el controller, lo movés al service.

**Service (`@Service`):**
- Contiene toda la lógica de negocio de ATENAS
- Los 19 pasos del `POST /v1/ventas` viven acá
- El cálculo retroactivo del líder vive acá
- Es el único lugar donde se toman decisiones de dominio
- Usa `@Transactional` para operaciones que deben ser atómicas

**Repository (`@Repository`):**
- Interfaz entre los objetos Java y PostgreSQL
- No escribe SQL manualmente (en la mayoría de los casos)
- Spring Data JPA implementa los métodos automáticamente

**Entity (`@Entity`):**
- Clase Java que mapea a una tabla de PostgreSQL
- Un campo → una columna
- `@Id`, `@Column`, `@ManyToOne`, `@OneToMany` → le dicen a Hibernate cómo mapear

**Paquetes adicionales:**

| Paquete | Contenido |
|---|---|
| `dto/` | Objetos de entrada (request) y salida (response). Nunca exponer Entity directo. |
| `exception/` | Excepciones custom (`VentaInvalidaException`) + `GlobalExceptionHandler` |
| `config/` | `SecurityConfig`, `CorsConfig`, `JwtConfig` |
| `scheduler/` | Cron job semanal (`@Scheduled`) |
| `util/` | `JwtUtil`, generador de código `EF-YYYYMMDD-NNNNN` |

---

## 4.4 — La capa Repository: Spring Data JPA

El Repository es una **interfaz**, no una clase con implementación. Spring Data JPA genera la implementación automáticamente en tiempo de ejecución, leyendo el nombre de los métodos.

```java
@Repository
public interface VentaRepository extends JpaRepository<Venta, UUID> {

    // Spring genera: SELECT * FROM venta WHERE vendedor_id = ?
    List<Venta> findByVendedorId(UUID vendedorId);

    // Spring genera: SELECT * FROM venta WHERE vendedor_id = ? AND semana_laboral_id = ?
    List<Venta> findByVendedorIdAndSemanaLaboral_Id(UUID vendedorId, UUID semanaId);

    // Para queries complejas, JPQL (Java Persistence Query Language)
    @Query("SELECT v FROM Venta v WHERE v.estado = 'PENDIENTE' ORDER BY v.fechaHoraRegistro ASC")
    List<Venta> findPendientesOrdenadas();

    // O SQL nativo si necesitás algo muy específico de PostgreSQL
    @Query(value = "SELECT * FROM venta WHERE fecha_baja IS NULL LIMIT :limit", nativeQuery = true)
    List<Venta> findActivasConLimite(@Param("limit") int limit);
}
```

`JpaRepository<Venta, UUID>` ya provee sin que escribas nada:

| Método | Descripción |
|---|---|
| `save(venta)` | INSERT o UPDATE según si tiene ID |
| `findById(id)` | SELECT por PK → devuelve `Optional<Venta>` |
| `findAll()` | SELECT todos |
| `delete(venta)` | DELETE |
| `count()` | COUNT(*) |

**La regla de oro del Repository:**
Solo contiene consultas a la BD. Ninguna lógica de negocio. Si necesitás decidir algo con los datos que devuelve, esa decisión vive en el Service.

---

### 🔖 Para explorar después del proyecto
- Ver con `spring.jpa.show-sql=true` el SQL que Hibernate genera por cada llamada al Repository
- Comparar `@Query` JPQL vs SQL nativo: cuándo usar cada uno
- `Optional<T>` como patrón: cómo evitar NullPointerException al buscar por ID
- Constructor Injection vs `@Autowired` en campo: por qué el constructor es la forma recomendada en Spring Boot 3.x

---

## 4.5 — El primer endpoint: envelope, `@RestController` y Spring Security

Esta sección documenta el Bloque 1: el primer endpoint REST funcionando (`GET /v1/health`).

### El envelope de respuesta (DTO genérico)

**¿Qué es un DTO?** *Data Transfer Object*. Una clase que solo transporta datos: sin lógica, sin anotaciones JPA, sin nada del dominio. Es lo que los endpoints reciben y devuelven.

**Regla de oro:** nunca exponer una `@Entity` directo en un endpoint. Rompe la separación de capas y puede filtrar campos que no deben salir (como `password_hash`). Siempre se traduce Entity → DTO antes de responder.

**El envelope** es un DTO que envuelve *toda* respuesta de la API con una estructura uniforme. En ATENAS:

```java
@Getter
@JsonInclude(JsonInclude.Include.NON_NULL)  // omite del JSON los campos null
public class ApiResponse<T> {
    private final boolean success;
    private final T data;
    private final String message;
    private final String errorCode;
    private final Object errors;

    private ApiResponse(...) { ... }  // constructor privado

    // Métodos estáticos de fábrica — la única forma de crear un ApiResponse
    public static <T> ApiResponse<T> ok(T data) { ... }
    public static <T> ApiResponse<T> ok(T data, String message) { ... }
    public static ApiResponse<Void> error(String message, String errorCode) { ... }
}
```

**Conceptos clave del envelope:**

| Concepto | Qué hace | Por qué |
|---|---|---|
| `<T>` (genérico) | El campo `data` puede ser de cualquier tipo | El mismo envelope sirve para devolver una venta, una lista, un mapa, etc. |
| Constructor privado + métodos estáticos | Nadie hace `new ApiResponse(...)` | Fuerza a crear respuestas solo de formas válidas y legibles: `ApiResponse.ok(data)` |
| `@JsonInclude(NON_NULL)` | Jackson omite campos `null` del JSON | Las respuestas exitosas no muestran `errorCode: null`, los errores no muestran `data: null` |
| `@Getter` (Lombok) | Genera los getters automáticamente | Jackson necesita getters para serializar a JSON. **Sin getters, el JSON sale vacío `{}`** |

### `@RestController` vs MVC clásico

```java
@RestController          // = @Controller + @ResponseBody
@RequestMapping("/v1")   // prefijo base para todos los endpoints de esta clase
public class HealthController {

    @GetMapping("/health")   // mapea GET /v1/health
    public ApiResponse<Map<String, String>> health() {
        return ApiResponse.ok(data, "Sistema operativo");
    }
}
```

`@RestController` combina dos anotaciones:
- `@Controller` → Spring registra la clase como componente web que maneja requests HTTP.
- `@ResponseBody` → el valor de retorno se serializa a JSON automáticamente (lo hace Jackson, incluido en `spring-boot-starter-web`).

**La diferencia con el MVC clásico:** sin `@ResponseBody`, Spring interpretaría el retorno como el *nombre de una vista* (un archivo HTML a renderizar). Con `@RestController`, siempre se devuelve el objeto serializado a JSON. Para una API REST, siempre `@RestController`.

### Spring Security: el filter chain

**El concepto mental:** Spring Security es un portero que intercepta *cada* request HTTP **antes** de que llegue a tu controller. Por defecto, ese portero bloquea todo y redirige a un formulario de login. Por eso, apenas agregás la dependencia de Security, todos los endpoints quedan protegidos sin que hagas nada.

`SecurityConfig` define las **reglas del portero**:

```java
@Configuration       // Spring lee esta clase como fuente de configuración al arrancar
@EnableWebSecurity
public class SecurityConfig {

    @Bean   // el objeto que retorna este método se registra en el contenedor IoC
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/v1/health", "/v1/auth/**").permitAll()
                .anyRequest().authenticated()
            );
        return http.build();
    }
}
```

**Las tres decisiones de este bloque:**

| Línea | Qué hace | Por qué en ATENAS |
|---|---|---|
| `csrf.disable()` | Desactiva la protección CSRF | CSRF es un ataque específico de formularios HTML. Una API REST con tokens/cookies HttpOnly no lo necesita |
| `sessionCreationPolicy(STATELESS)` | Security no crea ni busca sesiones HTTP | Cada request se autentica solo con su JWT (Bloque 3). No hay estado de sesión en el servidor |
| `authorizeHttpRequests(...)` | Define qué endpoints son públicos y cuáles requieren login | `/v1/health` y `/v1/auth/**` quedan públicos; todo lo demás exige autenticación |

**Importante sobre el orden:** las reglas dentro de `authorizeHttpRequests` se evalúan de arriba hacia abajo. La primera que coincide gana. Por eso los `permitAll()` específicos van **antes** del `anyRequest().authenticated()` general.

**Nota sobre el log de arranque:** mientras no haya autenticación JWT implementada, Spring Boot sigue mostrando `Using generated security password: ...` al arrancar. No es un error: es el fallback de login básico de Security. El endpoint público funciona igual. Se elimina del todo en el Bloque 3 al reemplazar el mecanismo de autenticación por JWT.

---

### 🔖 Para explorar después del Bloque 1
- Métodos de fábrica estáticos (*static factory methods*) vs constructores públicos: por qué Effective Java los recomienda
- Genéricos en Java (`<T>`): variancia, wildcards (`? extends`, `? super`)
- El orden de los filtros en la `SecurityFilterChain`: qué filtros corren antes y después del de autorización
- `application.yml`: bajar el nivel de log de Security con `logging.level.org.springframework.security: WARN`

---

*Fin de la Fase 4 — actualizada al cierre del Bloque 1.*
*Próximo: Fase 4.6 — Entidades JPA (mapeo Entity ↔ tabla, FK circular equipo ↔ usuario).*
