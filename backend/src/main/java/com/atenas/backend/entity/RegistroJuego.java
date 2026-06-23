package com.atenas.backend.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "registro_juego")
@Getter
@Setter
@NoArgsConstructor
public class RegistroJuego {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "juego_id", nullable = false)
    private Juego juego;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "vendedor_id", nullable = false)
    private Usuario vendedor;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "robo_de_id")
    private Usuario roboDe;

    @Column(name = "puntos", nullable = false)
    private Integer puntos;

    @Column(name = "url_foto", length = 500)
    private String urlFoto;

    @Column(name = "fecha", nullable = false, updatable = false)
    private OffsetDateTime fecha;
}