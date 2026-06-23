package com.atenas.backend.entity;

import com.atenas.backend.entity.enums.MonedaTipo;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity                          // (1) "Esta clase es una tabla de BD"
@Table(name = "pais")            // (2) nombre exacto de la tabla en PostgreSQL
@Getter                          // (3) Lombok genera solo getters
@Setter                          // (4) Lombok genera solo setters
@NoArgsConstructor               // (5) Lombok genera constructor vacío (JPA lo necesita)
public class Pais {

    @Id                                                    // (6) Esta es la PK
    @GeneratedValue(strategy = GenerationType.UUID)        // (7) UUID autogenerado
    @Column(name = "id")
    private UUID id;

    @Column(name = "nombre", nullable = false, length = 100)
    private String nombre;

    @Enumerated(EnumType.STRING)           // (8) Guarda "CLP" o "ARS", no 0 o 1
    @Column(name = "moneda", nullable = false)
    private MonedaTipo moneda;

    @Column(name = "fecha_baja")           // (9) Soft delete: NULL = activo
    private OffsetDateTime fechaBaja;
}