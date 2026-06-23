package com.atenas.backend.entity;

import com.atenas.backend.entity.enums.AutorizacionOrigen;
import com.atenas.backend.entity.enums.FormaPagoTipo;
import com.atenas.backend.entity.enums.MonedaTipo;
import com.atenas.backend.entity.enums.VentaEstado;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "venta")
@Getter
@Setter
@NoArgsConstructor
public class Venta {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "vendedor_id", nullable = false)
    private Usuario vendedor;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "cupon_id", nullable = false)
    private Cupon cupon;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "cliente_id")
    private Cliente cliente;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "semana_laboral_id", nullable = false)
    private SemanaLaboral semanaLaboral;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "punto_de_venta_id", nullable = false)
    private PuntoDeVenta puntoDeVenta;

    @Enumerated(EnumType.STRING)
    @Column(name = "forma_pago", nullable = false)
    private FormaPagoTipo formaPago;

    @Column(name = "numero_autorizacion", nullable = false, length = 100)
    private String numeroAutorizacion;

    @Enumerated(EnumType.STRING)
    @Column(name = "origen_autorizacion", nullable = false)
    private AutorizacionOrigen origenAutorizacion;

    @Column(name = "aplico_descuento", nullable = false)
    private Boolean aplicoDescuento;

    @Column(name = "precio_final", nullable = false, precision = 12, scale = 2)
    private BigDecimal precioFinal;

    @Enumerated(EnumType.STRING)
    @Column(name = "moneda", nullable = false)
    private MonedaTipo moneda;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado", nullable = false)
    private VentaEstado estado;

    @Column(name = "fuera_de_campana", nullable = false)
    private Boolean fueraDeCampana;

    @Column(name = "fecha_hora_registro", nullable = false, updatable = false)
    private OffsetDateTime fechaHoraRegistro;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "secretario_validador_id")
    private Usuario secretarioValidador;

    @Column(name = "fecha_hora_validacion")
    private OffsetDateTime fechaHoraValidacion;

    @Column(name = "observaciones_validacion", columnDefinition = "TEXT")
    private String observacionesValidacion;

    // v1.3: trazabilidad efectivo → rendición (solo ventas EFECTIVO). Nullable.
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "rendicion_efectivo_id")
    private RendicionEfectivo rendicionEfectivo;

    // v1.3: enlace al día del dashboard. Nullable para datos históricos pre-sistema.
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "jornada_vendedor_id")
    private JornadaVendedor jornadaVendedor;
}