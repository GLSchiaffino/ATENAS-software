package com.atenas.backend.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "tabla_comision")
@Getter
@Setter
@NoArgsConstructor
public class TablaComision {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    @Column(name = "precio_venta", nullable = false, unique = true, precision = 12, scale = 2)
    private BigDecimal precioVenta;

    @Column(name = "monto_comision", nullable = false, precision = 12, scale = 2)
    private BigDecimal montoComision;

    @Column(name = "fecha_baja")
    private OffsetDateTime fechaBaja;
}