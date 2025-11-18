#include "stdafx.h"
#include "WaterObject.h"
#include "Scene.h"
#include "Object.h"

CWaterObject::CWaterObject(ID3D12Device* pd3dDevice, ID3D12GraphicsCommandList* pd3dCommandList, ID3D12RootSignature* pd3dGraphicsRootSignature, CWaterShader* pWaterShader, float fWidth, float fLength) : CGameObject(1, 1)
{
    CTexturedRectMesh* pWaterMesh = new CTexturedRectMesh(pd3dDevice, pd3dCommandList, fWidth, 0.0f, fLength, 0.0f, 0.0f, 0.0f);
    SetMesh(0, pWaterMesh);

    CTexture* pWaterTexture = new CTexture(3, RESOURCE_TEXTURE2D, 0, 1);

    pWaterTexture->LoadTextureFromDDSFile(pd3dDevice, pd3dCommandList, L"Terrain/Water_Base_Texture_0.dds", RESOURCE_TEXTURE2D, 0); // t6
    pWaterTexture->LoadTextureFromDDSFile(pd3dDevice, pd3dCommandList, L"Terrain/Water_Detail_Texture_0.dds", RESOURCE_TEXTURE2D, 1); // t7
    pWaterTexture->LoadTextureFromDDSFile(pd3dDevice, pd3dCommandList, L"Terrain/WaveFoam.dds", RESOURCE_TEXTURE2D, 2); // t8

    
    CScene::CreateShaderResourceViews(pd3dDevice, pWaterTexture, 0, 13); 

    CMaterial* pWaterMaterial = new CMaterial();
    pWaterMaterial->SetTexture(pWaterTexture);
    pWaterMaterial->SetShader(pWaterShader);    

    if (m_nMaterials == 0) {
        m_nMaterials = 1;
        m_ppMaterials = new CMaterial*[m_nMaterials];
        m_ppMaterials[0] = NULL;
        
    } else if (m_ppMaterials == NULL) {
        m_ppMaterials = new CMaterial*[m_nMaterials];
        m_ppMaterials[0] = NULL;
        
    }

    SetMaterial(0, pWaterMaterial);
}

CWaterObject::~CWaterObject()
{
}
