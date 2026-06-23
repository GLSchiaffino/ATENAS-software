package com.atenas.backend.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "imagen_venta")
@Getter
@Setter
@NoArgsConstructor
public class ImagenVenta {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "venta_id", nullable = false)
    private Venta venta;

    @Column(name = "url_almacenamiento", nullable = false, length = 500)
    private String urlAlmacenamiento;

    @Column(name = "tamanio_bytes", nullable = false)
    private Integer tamanioBytes;

    @Column(name = "fecha_subida", nullable = false, updatable = false)
    private OffsetDateTime fechaSubida;
}