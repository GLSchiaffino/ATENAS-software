package com.atenas.backend.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "umbral_lider")
@Getter
@Setter
@NoArgsConstructor
public class UmbralLider {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    // v1.4: solo límite inferior. Lookup: mayor ventas_desde <= ventas_semana_actual.
    @Column(name = "ventas_desde", nullable = false, unique = true)
    private Integer ventasDesde;

    @Column(name = "monto_comision_lider", nullable = false, precision = 12, scale = 2)
    private BigDecimal montoComisionLider;

    @Column(name = "fecha_baja")
    private OffsetDateTime fechaBaja;
}