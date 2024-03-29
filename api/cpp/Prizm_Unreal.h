// This file uses Unreal Engine 5.0 coding standards https://docs.unrealengine.com/5.0/en-US/epic-cplusplus-coding-standard-for-unreal-engine/

#ifndef PRIZM_UNREAL_API
#define PRIZM_UNREAL_API

#include <CoreMinimal.h> // FString

#ifndef PRIZM_UNREAL_API_EXCLUDE_ENGINE_MODULE
#include "GameFramework/Actor.h"
#include "Engine/StaticMesh.h"
#include "Components/StaticMeshComponent.h"
#include "StaticMeshResources.h"
#include "Rendering/PositionVertexBuffer.h"
#endif // PRIZM_UNREAL_API_EXCLUDE_ENGINE_MODULE

// We use excluding defines like to have everything in one file, which means that we can change the PRIZM_VECX_CLASS_EXTRA macros
// depending on the modules which get included. TODO Figure out a simple alternative way to extend these macros which allows for
// the code for different Unreal modules to be in separate files
#ifndef PRIZM_UNREAL_API_EXCLUDE_GEOMETRYCORE_MODULE
#include <VectorTypes.h>
#include <BoxTypes.h>
#include <DynamicMesh/DynamicMesh3.h>
#include <DynamicMesh/DynamicMeshOverlay.h>
#include <DynamicMesh/DynamicMeshAttributeSet.h>
#include <Image/ImageDimensions.h>
#include <Util/CompactMaps.h>
#endif // PRIZM_UNREAL_API_EXCLUDE_GEOMETRYCORE_MODULE

// The macros below must be defined before including "Prizm.h". This compile time error enforces this
#ifdef PRIZM_API
#error Prizm_Unreal.h must be included before Prizm.h because it defines macros used by the Prizm.h
#endif

// TODO Add a Vec3i? constructed from UE::Geometry::FIndex3i, in GeometryCore

#define PRIZM_VEC2_CLASS_EXTRA\
	Vec2(UE::Math::TVector2<T> p) : Vec2(p.X, p.Y) {}

#define PRIZM_VEC3_CLASS_EXTRA\
	Vec3(UE::Math::TVector<T> p) : Vec3(p.X, p.Y, p.Z) {}

#define PRIZM_VEC4_CLASS_EXTRA\
	Vec4(UE::Math::TVector4<T> p) : Vec4(p.X, p.Y, p.Z, p.W) {}

#define PRIZM_COLOR_CLASS_EXTRA\
	Color(FColor c) : Color(c.R, c.G, c.B, c.A) {}

// These are named to match Unreal coding standards, we can't overload anyway since this would infinitly recurse
#define PRIZM_OBJ_CLASS_EXTRA\
	Obj& Write(const FString& Filename) { return write(TCHAR_TO_UTF8(*Filename)); }\
	Obj& Add(const FString& Data) { return add(std::string(TCHAR_TO_UTF8(*Data))); }\
	Obj& Insert(const FString& Data) { return insert(std::string(TCHAR_TO_UTF8(*Data))); }

#include "Prizm.h"

namespace Prizm
{

bool DocumentationForUnreal(bool bWriteFiles)
{
	// This block shows how to work with Unreal vector types
	{
		using namespace Prizm;
		Prizm::Obj Obj;

		// Define some Unreal data types
		FVector   A(0,0,1),  B(1,0,1),  C(0,1,1);
		FVector3f D(0,0,2),  E(1,0,2),  F(0,1,2);
		FVector3d G(0,0,3),  H(1,0,3),  I(0,1,3);

		// This is the recommended way of passing Unreal vectors to the Prizm::Obj API
		Obj.triangle3(V3(A), V3(B), V3(C));

		// You could also do the following but in this case you will need to specify the template parameter, this is
		// sometimes more convenient than wrapping everything in a V3
		Obj.triangle3<float>(D, E, F);

		// Note that if you use Obj::add or Obj::insert with Unreal vectors you must construct Prizm's vector types
		// first. You might encounter this if you're doing some low-level stuff and forgot about Obj::vector3.
		Obj.v().insert(V3(G));
		Obj.v().insert(V3(H));
		Obj.v().insert(V3(I));
		Obj.triangle();

		// Uncomment this line to see the error message about missing operator<< you get if you omit this wrapping :(
		//Obj.v().insert(I);

		// For functions using Prizm::Color you can directly pass a FColor, you don't need to construct Prizm's Color type,
		// so both of the following work:
		Obj.set_vertex_label_color(FColor::Red);
		Obj.set_triangle_label_color(Color(FColor::Blue)); // Works, but redundant and verbose

		Obj.set_vertex_index_labels_visible(true);
		Obj.set_triangle_index_labels_visible(true);

		if (bWriteFiles) {
			Obj.write("prizm_DocumentationForUnreal_Ex1.obj");
		}
	}

	// This is a handy way to write FStrings to files in Unreal
	{
		FString Data;
		Data += "Here";
		Data += "Comes";
		Data += "Some Data";
		if (bWriteFiles) {
			Prizm::Obj().Add(Data).write("E:/Debug/prizm_DocumentationForUnreal_Ex2.txt");
		}
	}

#ifndef PRIZM_UNREAL_API_EXCLUDE_GEOMETRYCORE_MODULE
	// This block shows some of the provided functions for Geometry Core
	{
		// @Incomplete
	}
#endif // PRIZM_UNREAL_API_EXCLUDE_GEOMETRYCORE_MODULE

	return true;
}


#ifndef PRIZM_UNREAL_API_EXCLUDE_ENGINE_MODULE
struct FMakeActorObjOptions
{
	// If true/false write triangles using -/+ indices to reference vertex data. See Obj::use_negative_indices documentation
	bool bUseNegativeIndices = true;
};

Obj MakeActorObj(AActor* Actor, FString* OutMeshName = nullptr, FMakeActorObjOptions Options = {})
{
	Obj Result;

	if (!Actor)
	{
		return Result;
	}

	UStaticMeshComponent* MeshComponent = Actor->FindComponentByClass<UStaticMeshComponent>();

	if (MeshComponent)
	{
		UStaticMesh* StaticMesh = MeshComponent->GetStaticMesh();
		if (StaticMesh)
		{
			if (OutMeshName)
			{
				*OutMeshName = StaticMesh->GetName();
			}

			const FTransform ActorTransform = Actor->GetTransform();
			const FPositionVertexBuffer& Vertices = StaticMesh->GetRenderData()->LODResources[0].VertexBuffers.PositionVertexBuffer;
			const FIndexArrayView& Triangles = StaticMesh->GetRenderData()->LODResources[0].IndexBuffer.GetArrayView();

			if (Options.bUseNegativeIndices)
			{
				for (uint32 i = 0; i < (uint32)Triangles.Num(); i += 3)
				{
					V3 a(ActorTransform.TransformPosition(FVector(Vertices.VertexPosition(Triangles[i]))));
					V3 b(ActorTransform.TransformPosition(FVector(Vertices.VertexPosition(Triangles[i+1]))));
					V3 c(ActorTransform.TransformPosition(FVector(Vertices.VertexPosition(Triangles[i+2]))));
					Result.triangle3(a, b, c);
				}
			}
			else
			{
				for (uint32 i = 0; i < Vertices.GetNumVertices(); i++)
				{
					Result.vertex3(V3(ActorTransform.TransformPosition(FVector(Vertices.VertexPosition(i)))));
				}

				for (uint32 i = 0; i < (uint32)Triangles.Num(); i += 3)
				{
					Result.triangle(Triangles[i]+1, Triangles[i+1]+1, Triangles[i+2]+1);
				}
			}
		}
	}

	return Result;
}
#endif // PRIZM_UNREAL_API_EXCLUDE_ENGINE_MODULE

#ifndef PRIZM_UNREAL_API_EXCLUDE_GEOMETRYCORE_MODULE
struct FMakeDynamicMeshObjOptions
{
	// If true reverses the orientation of the faces
	bool bReverseOrientation = true;

	// If true will attempt to write the per-vertex normals and UVs to the OBJ instead of the per-element values
	bool bWritePerVertexValues = true;

	// If true write "VID X" annotations on the OBJ v-directives, where X is the Vid into the input mesh (before the CompactCopy)
	bool bWriteVidAnnotations = false;

	// If true write "TID X" annotations on the OBJ f-directives, where X is the Tid into the input mesh (before the CompactCopy)
	bool bWriteTidAnnotations = false;
};

// TODO Rewite this to use negative indices so that the result can be used with Obj::append
Obj MakeDynamicMeshObj(const UE::Geometry::FDynamicMesh3& InMesh, FMakeDynamicMeshObjOptions Options = FMakeDynamicMeshObjOptions{})
{
	using namespace UE::Geometry;

	Obj Result;

	// We should compact the mesh to make sure the order that we write the vertex/normal/uv indices into obj is
	// consistent with the storage order
	FDynamicMesh3 Mesh;
	FCompactMaps CompactInfo;
	Mesh.CompactCopy(InMesh, true, true, true, true, &CompactInfo);

	// Compute an additional mapping from the compact mesh triangles to the input mesh triangles
	// i.e the inverse of the FCompactMaps
	TMap<int32, int32> CompactToInputTriangles; // Mesh Tid -> InMesh Tid
	if (Options.bWriteTidAnnotations)
	{
		CompactToInputTriangles.Reserve(Mesh.TriangleCount());
		for (int32 TriangleID : InMesh.TriangleIndicesItr())
		{
			const int32 CompactTriangleID = CompactInfo.GetTriangleMapping(TriangleID);
			if (CompactTriangleID != FCompactMaps::InvalidID)
			{
				CompactToInputTriangles.Add(CompactTriangleID, TriangleID);
			}
		}
		checkSlow(CompactToInputTriangles.Num() == Mesh.TriangleCount());
	}

	TMap<int32, int32> CompactToInputVertices; // Mesh Vid -> InMesh Vid
	if (Options.bWriteVidAnnotations)
	{
		CompactToInputVertices.Reserve(Mesh.VertexCount());
		for (int32 VertexID : InMesh.VertexIndicesItr())
		{
			const int32 CompactVertexID = CompactInfo.GetVertexMapping(VertexID);
			if (CompactVertexID != FCompactMaps::InvalidID)
			{
				CompactToInputVertices.Add(CompactVertexID, VertexID);
			}
		}
		checkSlow(CompactToInputVertices.Num() == Mesh.VertexCount());
	}

	if (Options.bReverseOrientation)
	{
		Mesh.ReverseOrientation();
	}

	bool bHasVertexNormals = Options.bWritePerVertexValues && Mesh.HasVertexNormals();
	bool bHasVertexUVs = Options.bWritePerVertexValues && Mesh.HasVertexUVs();

	for (int32 VID = 0;  VID < Mesh.VertexCount(); ++VID)
	{
		check(Mesh.IsVertex(VID)); // mesh is not compact

		FVector3d Pos = Mesh.GetVertex(VID);
		Result.vertex3(V3(Pos));
		if (Options.bWriteVidAnnotations)
		{
			// Note: Suffix indicates this is zero-based
			int32* InMeshVID0 = CompactToInputVertices.Find(VID);
			ensure(InMeshVID0 != nullptr);
			Result.annotation("VID").insert(*InMeshVID0);
		}

		if (bHasVertexNormals)
		{
			FVector3f Normal = Mesh.GetVertexNormal(VID);
			Result.normal3(V3f(Normal));
		}

		if (bHasVertexUVs)
		{
			FVector2f UV = Mesh.GetVertexUV(VID);
			Result.uv2(V2f(UV));
		}
	}

	const FDynamicMeshUVOverlay* UVs = nullptr;
	const FDynamicMeshNormalOverlay* Normals = nullptr;

	if (Options.bWritePerVertexValues == false && Mesh.Attributes())
	{
		UVs = Mesh.Attributes()->PrimaryUV();
		if (UVs)
		{
			for (int32 UI = 0; UI < UVs->ElementCount(); ++UI)
			{
				check(UVs->IsElement(UI))
				FVector2f UV = UVs->GetElement(UI);
				Result.uv2(V2f(UV));
			}
		}

		Normals = Mesh.Attributes()->PrimaryNormals();
		if (Normals)
		{
			for (int32 NI = 0; NI < Normals->ElementCount(); ++NI)
			{
				check(Normals->IsElement(NI));
				FVector3f Normal = Normals->GetElement(NI);
				Result.normal3(V3f(Normal));
			}
		}
	}

	for (int32 TID = 0; TID < Mesh.TriangleCount(); ++TID)
	{
		check(Mesh.IsTriangle(TID));

		FIndex3i TriVertices = Mesh.GetTriangle(TID);

		if (Options.bWritePerVertexValues)
		{
			if (bHasVertexNormals == false && bHasVertexUVs == false)
			{
				Result.triangle(
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1);
			}
			else if (bHasVertexNormals == true && bHasVertexUVs == false)
			{
				Result.triangle_vn(
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1,
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1);
			}
			else if (bHasVertexNormals == false && bHasVertexUVs == true)
			{
				Result.triangle_vt(
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1,
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1);
			}
			else
			{
				Result.triangle_vnt(
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1,
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1,
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1);
			}
		}
		else
		{
			bool bHaveUV = UVs && UVs->IsSetTriangle(TID);
			bool bHaveNormal = Normals && Normals->IsSetTriangle(TID);

			FIndex3i TriUVs = bHaveUV ? UVs->GetTriangle(TID) : FIndex3i::Invalid();
			FIndex3i TriNormals = bHaveNormal ? Normals->GetTriangle(TID) : FIndex3i::Invalid();

			if (bHaveUV && bHaveNormal)
			{
				Result.triangle_vnt(
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1,
					TriNormals.A+1, TriNormals.B+1, TriNormals.C+1,
					TriUVs.A+1, TriUVs.B+1, TriUVs.C+1);
			}
			else if (bHaveUV)
			{
				Result.triangle_vt(
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1,
					TriUVs.A+1, TriUVs.B+1, TriUVs.C+1);
			}
			else if (bHaveNormal)
			{
				Result.triangle_vnt(
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1,
					TriNormals.A+1, TriNormals.B+1, TriNormals.C+1);
			}
			else
			{
				Result.triangle(
					TriVertices.A+1, TriVertices.B+1, TriVertices.C+1);
			}
		}
		if (Options.bWriteTidAnnotations)
		{
			// Note: Suffix indicates this is zero-based
			int32* InMeshTID0 = CompactToInputTriangles.Find(TID);
			ensure(InMeshTID0 != nullptr);
			Result.annotation("TID").insert(*InMeshTID0);
		}
	}

	// Set some useful item state in Prizm via command annotations
 	// You could further configure the Prizm item state at the call site before you call Obj::write()
	// Note the lines written by the following code are ignored by other obj viewers

	if (Options.bWriteVidAnnotations)
	{
		Result.set_vertex_annotations_visible(true);
	}
	
	if (Options.bWriteTidAnnotations)
	{
		Result.set_triangle_annotations_visible(true);
	}
	Result.set_edges_width(true);
	Result.set_edges_visible(true);

	return Result;
}




struct FMakeDynamicMeshOverlayObjOptions
{
	// Controls how far the overlay's annotated points are perturbed along the parent triangle normal
	// This value is multiplied by the parent mesh diagonal bounds length and then multiplied by the triangle normal vector
	double OverlayPointNormalOffsetScaleMultiplier = 0.;

	// If the annotated point is at P, and corresponds to vertex A of triangle ABC, then this value represents area ratio PBC/ABC.
	// Use a value in the range (.333, 1). Values near 1 place P near A; values near .333 place P near the triangle centroid
	double OverlayPointBaryCoord = .95;

	// If true reverses the orientation of the faces.
	// Warning! This is @Incomplete, and not implemented sorry
	bool bReverseOrientation = false;
};

// Write the Overlay parent mesh triangles and then add annotated point elements encoding the overlay info:
// The overlay element ids and element values are encoded as annotations with the format "@ <ElementID> @ <ElementValue>"
template<typename RealType, int ElementSize>
Obj MakeDynamicMeshOverlayObj(const UE::Geometry::TDynamicMeshOverlay<RealType, ElementSize>& Overlay, FMakeDynamicMeshOverlayObjOptions Options = FMakeDynamicMeshOverlayObjOptions{})
{
	using namespace UE::Geometry;

	Obj Result;

	if (Overlay.GetParentMesh() == nullptr)
	{
		return Result;
	}

	if (Options.bReverseOrientation)
	{
		ensure(false); // This option is not yet implemented, sorry!
	}

	FAxisAlignedBox3d Bounds = Overlay.GetParentMesh()->GetBounds();
	double Scale = Bounds.DiagonalLength();

	for (int32 TID = 0; TID < Overlay.GetParentMesh()->TriangleCount(); ++TID)
	{
		if (Overlay.GetParentMesh()->IsTriangle(TID))
		{
			FIndex3i ElementIDs = Overlay.GetTriangle(TID);

			RealType DataA[ElementSize];
			Overlay.GetElement(ElementIDs.A, DataA);

			RealType DataB[ElementSize];
			Overlay.GetElement(ElementIDs.B, DataB);

			RealType DataC[ElementSize];
			Overlay.GetElement(ElementIDs.C, DataC);

			FVector3d Centroid = Overlay.GetParentMesh()->GetTriCentroid(TID);
			FIndex3i Verts = Overlay.GetParentMesh()->GetTriangle(TID);


			FVector3d A = Overlay.GetParentMesh()->GetVertex(Verts.A);
			FVector3d B = Overlay.GetParentMesh()->GetVertex(Verts.B);
			FVector3d C = Overlay.GetParentMesh()->GetVertex(Verts.C);
			/*
			FVector3d AB = UE::Geometry::Lerp(A, B, .5);
			FVector3d BC = UE::Geometry::Lerp(B, C, .5);
			FVector3d CA = UE::Geometry::Lerp(C, A, .5);
			*/

			Result.triangle3<double>(A, B, C); // No annotation here, just for viz and to stop visibility checks

			const double BaryVertex = Options.OverlayPointBaryCoord; // Bary coords for the annotated vertex
			const double BaryEdge = (1. - Options.OverlayPointBaryCoord) / 2.; // Bary coords corresponding to the vertices on the opposite edge
			const FVector3d NormalOffset = Overlay.GetParentMesh()->GetTriNormal(TID) * Scale * Options.OverlayPointNormalOffsetScaleMultiplier;

			// Result.polygon3(4, V3(A), V3(CA), V3(Centroid), V3(AB));
			Result.point3<double>(Overlay.GetParentMesh()->GetTriBaryPoint(TID, BaryVertex, BaryEdge, BaryEdge) + NormalOffset);
			Result.attribute(ElementIDs.A);
			Result.attribute();
			for (int i = 0; i < ElementSize; i++)
			{
				int OldPrecision;
				Result.set_precision(4, &OldPrecision);
				Result.insert(DataA[i]);
				Result.set_precision(OldPrecision);
			}

			// Result.polygon3(4, V3(B), V3(AB), V3(Centroid), V3(BC));
			Result.point3<double>(Overlay.GetParentMesh()->GetTriBaryPoint(TID, BaryEdge, BaryVertex, BaryEdge) + NormalOffset);
			Result.attribute(ElementIDs.B);
			Result.attribute();
			for (int i = 0; i < ElementSize; i++)
			{
				int OldPrecision;
				Result.set_precision(4, &OldPrecision);
				Result.insert(DataB[i]);
				Result.set_precision(OldPrecision);
			}

			// Result.polygon3(4, V3(C), V3(BC), V3(Centroid), V3(CA));
			Result.point3<double>(Overlay.GetParentMesh()->GetTriBaryPoint(TID, BaryEdge, BaryEdge, BaryVertex) + NormalOffset);
			Result.attribute(ElementIDs.C);
			Result.attribute();
			for (int i = 0; i < ElementSize; i++)
			{
				int OldPrecision;
				Result.set_precision(4, &OldPrecision);
				Result.insert(DataC[i]);
				Result.set_precision(OldPrecision);
			}
		}
	}

	// Set some useful item state in Prizm via command annotations
	// You could further configure the Prizm item state at the call site before you call Obj::write()
	// Note the lines written by the following code are ignored by other obj viewers
	Result.set_point_annotations_visible(true);
	Result.set_edges_width(true);
	Result.set_edges_visible(true);

	return Result;
}




struct FMakeImageDimensionsObjOptions
{
	// If true adds point elements at the texel centers with an annotation showing the texel UV coordinates e.g., "UV(0.123 0.5)"
	bool bAnnotateTexelCentersWithUVCoordinates = true;

	// If true adds point elements at the texel centers with an annotation showing the texel index e.g., "Idx(3 7)"
	bool bAnnotateTexelCentersWithTexelIndex = true;

	// Digits of precision used when writing UV coordinates to annotations (See bAnnotateTexelCentersWithUVCoordinates)
	int UVAnnotationPrecision = 3;
};

// Returns a Prizm::Obj which only uses negative element indices which means the result can be used with Prizm::Obj::append
Obj MakeImageDimensionsObj(UE::Geometry::FImageDimensions Dims, FMakeImageDimensionsObjOptions Options = FMakeImageDimensionsObjOptions{})
{
	using namespace UE::Geometry;

	Obj Result;

	FVector2d TexelExtentUV = Dims.GetTexelSize();

	for (int LinearIndex = 0; LinearIndex < Dims.Num(); LinearIndex++)
	{
		FVector2i TexelIndex = Dims.GetCoords(LinearIndex);
		FVector2d TexelCenterUV = Dims.GetTexelUV(TexelIndex);
		Result.box2_center_extents(V2(TexelCenterUV), V2(TexelExtentUV));

		if (Options.bAnnotateTexelCentersWithUVCoordinates ||
			Options.bAnnotateTexelCentersWithTexelIndex)
		{
			Result.point2(V2(TexelCenterUV));
		}

		if (Options.bAnnotateTexelCentersWithTexelIndex)
		{
			Result.annotation("Idx(").add(V2(TexelIndex.X, TexelIndex.Y)).add(")"); // TODO Add a Prizm::V2i type
		}

		if (Options.bAnnotateTexelCentersWithUVCoordinates)
		{
			Result.set_precision(Options.UVAnnotationPrecision);
			Result.annotation("UV(").add(V2(TexelCenterUV)).add(")");
			Result.set_precision(); // Restore default precision
		}
	}

	// Set some useful item state in Prizm via command annotations
 	// You could further configure the Prizm item state at the call site before you call Obj::write()
	// Note the lines written by the following code are ignored by other obj viewers
	Result.set_annotations_visible(true);

	return Result;
}

#endif // PRIZM_UNREAL_API_EXCLUDE_GEOMETRYCORE_MODULE

} // namespace Prizm

#endif // PRIZM_UNREAL_API