package com.atenas.backend.entity;

import com.atenas.backend.entity.enums.MonedaTipo;
import com.atenas.backend.entity.enums.RendicionEstado;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "rendicion_efectivo")
@Getter
@Setter
@NoArgsConstructor
public class RendicionEfectivo {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "vendedor_id", nullable = false)
    private Usuario vendedor;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "lider_id", nullable = false)
    private Usuario lider;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "semana_laboral_id", nullable = false)
    private SemanaLaboral semanaLaboral;

    // v1.4: ABIERTA = creada automáticamente al 1er efectivo de la semana.
    //        CERRADA = el líder confirmó la recepción física.
    @Enumerated(EnumType.STRING)
    @Column(name = "estado", nullable = false)
    private RendicionEstado estado;

    // El monto se confirma al cerrar la rendición. NULL mientras ABIERTA.
    @Column(name = "monto", precision = 12, scale = 2)
    private BigDecimal monto;

    @Enumerated(EnumType.STRING)
    @Column(name = "moneda", nullable = false)
    private MonedaTipo moneda;

    @Column(name = "fecha_rendicion")
    private OffsetDateTime fechaRendicion;

    @Column(name = "observaciones", columnDefinition = "TEXT")
    private String observaciones;
}