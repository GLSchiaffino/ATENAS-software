package com.atenas.backend.entity;

import com.atenas.backend.entity.enums.ComisionTipo;
import com.atenas.backend.entity.enums.MonedaTipo;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "registro_comision")
@Getter
@Setter
@NoArgsConstructor
public class RegistroComision {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    // NULL para bonos y premios (no atados a una venta específica)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "venta_id")
    private Venta venta;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "beneficiario_id", nullable = false)
    private Usuario beneficiario;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "semana_laboral_id", nullable = false)
    private SemanaLaboral semanaLaboral;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo", nullable = false)
    private ComisionTipo tipo;

    @Column(name = "monto", nullable = false, precision = 12, scale = 2)
    private BigDecimal monto;

    @Enumerated(EnumType.STRING)
    @Column(name = "moneda", nullable = false)
    private MonedaTipo moneda;

    @Column(name = "fecha_calculo", nullable = false, updatable = false)
    private OffsetDateTime fechaCalculo;

    // v1.3: trazabilidad al pago (NULL mientras la semana está abierta)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "pago_vendedor_id")
    private PagoVendedor pagoVendedor;

    // v1.3: qué fila de tabla_comision generó este monto (auditoría histórica)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "tabla_comision_id")
    private TablaComision tablaComision;

    // v1.3: qué umbral del líder se aplicó (solo LIDER_EQUIPO)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "umbral_lider_id")
    private UmbralLider umbralLider;

    // v1.3: enlace al día del dashboard (obligatorio para bonos y premios sin venta)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "jornada_vendedor_id")
    private JornadaVendedor jornadaVendedor;
}