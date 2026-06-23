package com.atenas.backend.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "asignacion_equipo_punto")
@Getter
@Setter
@NoArgsConstructor
public class AsignacionEquipoPunto {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "punto_de_venta_id", nullable = false)
    private PuntoDeVenta puntoDeVenta;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "equipo_id", nullable = false)
    private Equipo equipo;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "semana_laboral_id", nullable = false)
    private SemanaLaboral semanaLaboral;

    @Column(name = "fecha_inicio", nullable = false)
    private OffsetDateTime fechaInicio;

    // v1.3: fecha_fin = NULL → asignación vigente
    @Column(name = "fecha_fin")
    private OffsetDateTime fechaFin;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "registrado_por_id", nullable = false)
    private Usuario registradoPor;
}