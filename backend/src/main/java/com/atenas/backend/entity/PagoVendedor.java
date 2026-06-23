package com.atenas.backend.entity;

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
@Table(name = "pago_vendedor")
@Getter
@Setter
@NoArgsConstructor
public class PagoVendedor {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "vendedor_id", nullable = false)
    private Usuario vendedor;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "semana_laboral_id", nullable = false)
    private SemanaLaboral semanaLaboral;

    // v1.3: renombrado de tesorero_id (gerencia también puede registrar pagos)
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "registrado_por_id", nullable = false)
    private Usuario registradoPor;

    @Column(name = "monto_comisiones_vendedor", nullable = false, precision = 12, scale = 2)
    private BigDecimal montoComisionesVendedor;

    // 0 para vendedores que no son líderes de equipo (nunca NULL)
    @Column(name = "monto_comisiones_equipo", nullable = false, precision = 12, scale = 2)
    private BigDecimal montoComisionesEquipo;

    @Column(name = "monto_bonos_finde", nullable = false, precision = 12, scale = 2)
    private BigDecimal montoBonosFinde;

    @Column(name = "monto_premios_juegos", nullable = false, precision = 12, scale = 2)
    private BigDecimal montoPremiosJuegos;

    // v1.4: efectivo cobrado en campo no rendido al líder → se descuenta del pago
    @Column(name = "monto_descuento_efectivo", nullable = false, precision = 12, scale = 2)
    private BigDecimal montoDescuentoEfectivo;

    @Column(name = "total", nullable = false, precision = 12, scale = 2)
    private BigDecimal total;

    @Enumerated(EnumType.STRING)
    @Column(name = "moneda", nullable = false)
    private MonedaTipo moneda;

    @Column(name = "fecha_pago", nullable = false)
    private LocalDate fechaPago;

    @Column(name = "fecha_registro", nullable = false, updatable = false)
    private OffsetDateTime fechaRegistro;
}