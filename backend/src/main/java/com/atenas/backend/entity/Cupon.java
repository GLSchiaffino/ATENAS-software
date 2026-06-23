package com.atenas.backend.entity;

import com.atenas.backend.entity.enums.CuponEstado;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "cupon")
@Getter
@Setter
@NoArgsConstructor
public class Cupon {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "clinica_id", nullable = false)
    private Clinica clinica;

    @Column(name = "precio", nullable = false, precision = 12, scale = 2)
    private BigDecimal precio;

    @Column(name = "permite_descuento", nullable = false)
    private Boolean permiteDescuento;

    @Column(name = "precio_con_descuento", precision = 12, scale = 2)
    private BigDecimal precioConDescuento;

    @Column(name = "prestaciones", nullable = false, length = 500)
    private String prestaciones;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado", nullable = false)
    private CuponEstado estado;

    @Column(name = "fecha_creacion", nullable = false, updatable = false)
    private OffsetDateTime fechaCreacion;

    @Column(name = "fecha_activacion")
    private OffsetDateTime fechaActivacion;

    @Column(name = "fecha_baja")
    private OffsetDateTime fechaBaja;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "creado_por_id", nullable = false)
    private Usuario creadoPor;
}