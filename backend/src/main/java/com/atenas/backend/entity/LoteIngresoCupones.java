package com.atenas.backend.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "lote_ingreso_cupones")
@Getter
@Setter
@NoArgsConstructor
public class LoteIngresoCupones {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "cupon_id", nullable = false)
    private Cupon cupon;

    @Column(name = "cantidad", nullable = false)
    private Integer cantidad;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "registrado_por_id", nullable = false)
    private Usuario registradoPor;

    @Column(name = "fecha_ingreso", nullable = false, updatable = false)
    private OffsetDateTime fechaIngreso;

    @Column(name = "observaciones", columnDefinition = "TEXT")
    private String observaciones;
}