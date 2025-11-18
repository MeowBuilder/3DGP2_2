#include "stdafx.h"
#include "BillboardObject.h"
#include "PointMesh.h" // For CPointMesh

CBillboardObject::CBillboardObject(ID3D12Device* pd3dDevice, ID3D12GraphicsCommandList* pd3dCommandList, ID3D12RootSignature* pd3dGraphicsRootSignature, XMFLOAT3 xmf3Position, CShader* pShader, CTexture* pTexture)
    : CGameObject(1, 1)
{
    XMFLOAT3* pxmf3Positions = new XMFLOAT3[1];
    pxmf3Positions[0] = xmf3Position;
    CMesh* pMesh = new CPointMesh(pd3dDevice, pd3dCommandList, 1, pxmf3Positions);
    SetMesh(0, pMesh);
    delete[] pxmf3Positions;

    CMaterial* pMaterial = new CMaterial();
    pMaterial->SetShader(pShader);
    pMaterial->SetTexture(pTexture);
    SetMaterial(0, pMaterial);

    SetPosition(xmf3Position);

    UpdateTransform(NULL);
}

CBillboardObject::~CBillboardObject()
{
}

void CBillboardObject::Render(ID3D12GraphicsCommandList* pd3dCommandList, CCamera* pCamera)
{
    XMFLOAT3 pos = GetPosition();


    CGameObject::Render(pd3dCommandList, pCamera);
}
