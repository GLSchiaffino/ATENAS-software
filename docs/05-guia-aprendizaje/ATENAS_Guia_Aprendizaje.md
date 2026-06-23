
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
