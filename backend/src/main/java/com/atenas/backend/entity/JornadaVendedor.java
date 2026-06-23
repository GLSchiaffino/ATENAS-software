package com.atenas.backend.entity;

import com.atenas.backend.entity.enums.InscripcionTipo;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "jornada_vendedor")
@Getter
@Setter
@NoArgsConstructor
public class JornadaVendedor {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "jornada_diaria_id", nullable = false)
    private JornadaDiaria jornadaDiaria;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "vendedor_id", nullable = false)
    private Usuario vendedor;

    @Column(name = "meta_ventas", nullable = false)
    private Integer metaVentas;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo_inscripcion", nullable = false)
    private InscripcionTipo tipoInscripcion;

    @Column(name = "record_superado_hoy", nullable = false)
    private Boolean recordSuperadoHoy;

    @Column(name = "fecha_inscripcion", nullable = false, updatable = false)
    private OffsetDateTime fechaInscripcion;
}