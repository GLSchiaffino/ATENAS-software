package com.atenas.backend.entity;

import com.atenas.backend.entity.enums.MovimientoTIipo;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "movimiento_cupon")
@Getter
@Setter
@NoArgsConstructor
public class MovimientoCupon {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "lote_id", nullable = false)
    private LoteIngresoCupones lote;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo", nullable = false)
    private MovimientoTIipo tipo;

    @Column(name = "cantidad", nullable = false)
    private Integer cantidad;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "equipo_id")
    private Equipo equipo;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vendedor_id")
    private Usuario vendedor;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "registrado_por_id", nullable = false)
    private Usuario registradoPor;

    @Column(name = "fecha", nullable = false, updatable = false)
    private OffsetDateTime fecha;

    @Column(name = "motivo", columnDefinition = "TEXT")
    private String motivo;
}