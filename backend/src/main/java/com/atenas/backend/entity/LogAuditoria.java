package com.atenas.backend.entity;

import com.atenas.backend.entity.enums.AuditoriaOperacion;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.UUID;

// Registro inmutable, append-only (RNF-010). Sin ON DELETE CASCADE.
@Entity
@Table(name = "log_auditoria")
@Getter
@Setter
@NoArgsConstructor
public class LogAuditoria {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "usuario_id", nullable = false)
    private Usuario usuario;

    @Enumerated(EnumType.STRING)
    @Column(name = "operacion", nullable = false)
    private AuditoriaOperacion operacion;

    @Column(name = "entidad_tipo", nullable = false, length = 50)
    private String entidadTipo;

    @Column(name = "entidad_id", nullable = false)
    private UUID entidadId;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "datos_anteriores", columnDefinition = "jsonb")
    private String datosAnteriores;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "datos_nuevos", nullable = false, columnDefinition = "jsonb")
    private String datosNuevos;

    @Column(name = "fecha_hora", nullable = false, updatable = false)
    private OffsetDateTime fechaHora;

    @Column(name = "ip_origen", length = 45)
    private String ipOrigen;
}