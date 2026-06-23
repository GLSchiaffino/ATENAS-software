package com.atenas.backend.entity;

import com.atenas.backend.entity.enums.JuegoEstado;
import com.atenas.backend.entity.enums.JuegoTipo;
import com.atenas.backend.entity.enums.MonedaTipo;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "juego")
@Getter
@Setter
@NoArgsConstructor
public class Juego {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo", nullable = false)
    private JuegoTipo tipo;

    @Column(name = "fecha", nullable = false)
    private LocalDate fecha;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado", nullable = false)
    private JuegoEstado estado;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "encargado_id", nullable = false)
    private Usuario encargado;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ganador_id")
    private Usuario ganador;

    @Column(name = "monto_premio", precision = 12, scale = 2)
    private BigDecimal montoPremio;

    @Enumerated(EnumType.STRING)
    @Column(name = "moneda")
    private MonedaTipo moneda;

    @Column(name = "fecha_cierre")
    private OffsetDateTime fechaCierre;
}