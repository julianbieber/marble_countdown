use bevy::{
    asset::RenderAssetUsages,
    prelude::*,
    render::{
        mesh::{Indices, PrimitiveTopology},
        render_resource::{AsBindGroup, ShaderRef},
    },
    sprite::{Material2d, Material2dPlugin},
};
use jiff::{RoundMode, Timestamp, TimestampDifference, Unit};

fn main() {
    App::new()
        .add_plugins(DefaultPlugins)
        .add_plugins(Material2dPlugin::<CustomBackgroundMaterial>::default())
        .add_systems(Startup, setup)
        .add_systems(Update, (text_update_system, update_time))
        .insert_resource(ClearColor(Color::srgb(0.0, 0.0, 0.0)))
        .run();
}

// Marker struct to help identify the FPS UI component, since there may be many Text components
#[derive(Component)]
struct CountDownText;

// Marker struct to help identify the color-changing Text component
#[derive(Component)]
struct AnimatedText;

#[derive(AsBindGroup, Asset, TypePath, Debug, Clone)]
struct CustomBackgroundMaterial {
    #[uniform(0)]
    time: f32,
}

/// Implement the `UiMaterial` trait for our custom material.
/// This tells Bevy's UI rendering system how to use this material.
impl Material2d for CustomBackgroundMaterial {
    fn fragment_shader() -> ShaderRef {
        // Provide the path to our custom fragment shader.
        "shaders/custom_background.wgsl".into()
    }
}

fn setup(
    mut commands: Commands,
    meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<CustomBackgroundMaterial>>,
) {
    // UI camera
    commands.spawn(Camera2d);
    commands.spawn((
        Mesh2d(setup_mesh_with_uvs(meshes)),
        MeshMaterial2d(materials.add(CustomBackgroundMaterial { time: 22.0 })),
        Transform::default(),
    ));

    // Text with multiple sections
    commands.spawn((
        // Create a Text with multiple child spans.
        Text::new("The tournament begins in"),
        TextFont {
            // This font is loaded and will be used instead of the default font.
            font_size: 42.0,
            ..default()
        },
        CountDownText,
    ));
}

fn update_time(
    time: Res<Time>,
    mut materials: ResMut<Assets<CustomBackgroundMaterial>>,
    q: Query<&MeshMaterial2d<CustomBackgroundMaterial>>,
) {
    for v in q.iter() {
        materials.get_mut(v.id()).unwrap().time = time.elapsed_secs();
    }
}

fn setup_mesh_with_uvs(mut meshes: ResMut<Assets<Mesh>>) -> Handle<Mesh> {
    let mut mesh = Mesh::new(
        PrimitiveTopology::TriangleList,
        RenderAssetUsages::default(),
    )
    .with_inserted_attribute(
        Mesh::ATTRIBUTE_POSITION,
        // Define vertex positions (x, y, z) - z is often 0 for 2D
        vec![
            [-500.0, -500.0, 0.0],
            [500.0, -500.0, 0.0],
            [500.0, 500.0, 0.0],
            [-500.0, 500.0, 0.0],
        ],
    )
    .with_inserted_attribute(
        Mesh::ATTRIBUTE_UV_0,
        vec![[0.0, 1.0], [1.0, 1.0], [1.0, 0.0], [0.0, 0.0]], // Example for a quad
    )
    .with_inserted_indices(Indices::U32(vec![0, 1, 2, 0, 2, 3])); // Define triangles

    // Add normals if required by your shader or the default pipeline
    mesh.insert_attribute(Mesh::ATTRIBUTE_NORMAL, vec![[0.0, 0.0, 1.0]; 4]); // Flat normals pointing up

    meshes.add(mesh)
}

fn text_update_system(mut query: Query<&mut Text, With<CountDownText>>) {
    let target_datetime_str = "2025-04-30T08:30:00Z";
    let target_ts: Timestamp = target_datetime_str.parse().unwrap();

    // Get the current timestamp
    let now_ts: Timestamp = Timestamp::now();

    // Calculate the duration until the target datetime
    let duration = now_ts
        .until(
            TimestampDifference::new(target_ts)
                .smallest(Unit::Second)
                .largest(Unit::Hour)
                .mode(RoundMode::Trunc),
        )
        .unwrap();

    // Extract the duration in days, hours, minutes, and seconds
    let hours = duration.get_hours();
    let minutes = duration.get_minutes();
    let seconds = duration.get_seconds();

    for mut span in &mut query {
        **span = format!(
            "Time until the tournament\n{} hours, {} minutes, {} seconds",
            hours, minutes, seconds
        );
    }
}
