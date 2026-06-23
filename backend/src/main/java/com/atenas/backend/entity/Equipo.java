package com.atenas.backend.entity;

import com.atenas.backend.entity.enums.EquipoCategoria;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "equipo")
@Getter
@Setter
@NoArgsConstructor
public class Equipo {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    @Column(name = "nombre", nullable = false, length = 150)
    private String nombre;

    @Column(name = "emoji", length = 10)
    private String emoji;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo", nullable = false)
    private EquipoCategoria tipo;

    // lider_id es nullable (NULL para equipos administrativos)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "lider_id")          // optional = true por defecto
    private Usuario lider;

    @Column(name = "fecha_baja")
    private OffsetDateTime fechaBaja;
}